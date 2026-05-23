# EgeSüt ERP — Mimari ve Execution Flow Haritası

**Tarih:** 2026-05-23  
**Analiz Aracı:** GitNexus (274 execution flow, 3173 sembol)  
**Durum:** Production MVP hazır (Sürü ✅, Üreme 🟡, Klinik 🟡, Stok ✅, Görev ✅)

---

## 1. Genel Mimari — 3 Katmanlı Stack

```
┌─────────────────────────────────────────────────────────┐
│  Frontend Layer                                         │
│  Vanilla JS (index.html + 6 JS modülü)                │
│  Single Page App, IndexedDB offline cache             │
└────────────┬────────────────────────────────────────────┘
             │ Supabase REST API
             │ RPC (stored procedures)
             ├─────────────────────────────────────────────┐
             │  Application Layer                          │
             │  RPC calls + state machine                  │
             │  Event delegation + async sync              │
             ├─────────────────────────────────────────────┤
             │  Backend Layer (PostgreSQL)                 │
             │  RPC'ler, Views, Triggers, Ledger          │
             │  SECURITY DEFINER, RLS policies            │
             └─────────────────────────────────────────────┘
                        │
            GitHub Pages │ Deploy
            (GitHub Actions)
```

### Frontend Modüller (6 Dosya, 2804 satır)

| Modül | Satır | Sorumluluk |
|-------|-------|-----------|
| **ui.js** | 2804 | DOM render, 150+ render fonksiyonu, modal'lar |
| **forms.js** | 938 | Form submit'ler, RPC çağrıları (28 submit fonksiyon) |
| **app.js** | 737 | App init, routing, global state, event delegation |
| **api.js** | 332 | Supabase client, pullTables, renderSafe, rpcOptimistic |
| **state.js** | 84 | AppState (EventEmitter), getState/setState |
| **config.js** | 68 | Sabitler (GRUP_PADOK, SPERMA_LISTESI, HEKIMLER, vb.) |

### Database Stack

- **Supabase PostgreSQL** — 30+ tablo, 40+ RPC, 15+ view, 20+ trigger
- **IndexedDB** (`egesut_v9`, ver=6) — offline okuma cache
- **Stok Ledger** — immutable migration (asla sil/iptal yok)
- **Migration** — 30+ dosya, `99999999999999_ground_truth.sql` canonical referans

---

## 2. Execution Flow Haritası (9 Ana Domain)

### Domain 1: Hayvan Yönetimi (Sürü)

**Ana Akış:** Hayvan ekleme → Hayvan kart detayı → Filtreleme → Grup/Padok yönetimi

**GitNexus Bulgusu:**
- **Entering Point:** `submitAnimal()`  (`forms.js:25-102`)
- **Process:** `SubmitAnimal → G (getAll) → IdbClearAndPut → emit:chip`
- **Integration:**
  - `rpcOptimistic("hayvan_ekle", params)` → backend RPC
  - `pullTables(['hayvanlar', 'tohumlama'])` — IDB cache update
  - `setState('animals', data)` — AppState yazma
  - `filterA()` — frontend filtreleme

**İş Akışı Detayı:**
```
1. Hayvan formu doldur (kupe, devlet, ırk, cinsiyet, doğum tarihi, grup, padok)
2. submitAnimal() → rpcOptimistic("hayvan_ekle", {...})
3. Backend: hayvan_ekle RPC
   - Yeni ID (UUID) üret
   - hayvanlar tablosuna ekle
   - islem_log kaydı ("HAYVAN_EKLE")
4. Frontend: IDB refresh → AppState update → filterA() render
```

**Kritik Kodlar:**
- `submitAnimal()` — `forms.js:25`
- `hayvan_ekle(p_kupe_no, ...)` — RPC, DB'de `SECURITY DEFINER`
- `filterA()` — `ui.js:694` (sürü filtresi, 41 satır)
- `g('animals_table')` — DOM render hedefi

**Risk:** Grup/padok eşlemeleri `GRUP_PADOK` sabitinde. Mismatch → validation fail.

---

### Domain 2: Tohumlama (Üreme Döngüsü)

**Ana Akış:** Kızgınlık → Tohumlama Kaydı → Gebelik Takibi → Doğum → Buzağı Kaydı

**GitNexus Bulgusu:**
- **Entering Point:** `submitInsem()` (`forms.js:156-195`)
- **Process:** `SubmitInsem → G (getAll) → renderTask → state update`
- **~~Multiple RPC Paths (Sorun!)~~** ✅ DONE (2026-05-23):
  - Path 1: `rpcOptimistic("tohumlama_kaydet")` ✅ (doğru)
  - Path 2: ~~`tohSonucGuncelle()`~~ ✅ silindi — tohSonuc() full RPC
  - Path 3: ~~`gebeIsaretKaydet()`~~ ✅ silindi — dead code temizlendi

**İş Akışı Detayı:**
```
KIZGINLıK KAYDı
  ↓ (rpc: kizginlik_kaydet)
TOHUMLAMA KAYDI
  ├─ sperma seç (stok'tan veya manuel)
  ├─ tohumlama_kaydet RPC
  │  ├─ Stok ledger düşer (varsa)
  │  └─ deneme_no otomatik artar
  └─ islem_log: TOHUMLAMA_KAYDI
       ↓ (trigger: 21./35. gün görevleri)
GEBELIK TAKİBİ
  ├─ tohumlama.sonuc = "Bekliyor"
  └─ tohumlama_sonuc_gebe(id) RPC
       → sonuc = "Gebe"
       → hayvan.grup update ("Gebe Düve")
       → islem_log: TOHUMLAMA_SONUC
            ↓
DOĞUM KAYDI (dogum_kaydet RPC)
  ├─ 1. dogum tablosuna ekle
  ├─ 2. Buzağıyı hayvanlar'a ekle (grup: Süt İçen)
  ├─ 3. tohumlama.sonuc = "Doğum Yaptı"
  └─ 4. 14 görev trigger (doğum + buzağı bakım)
```

**Kritik Fonksiyonlar:**
- `submitInsem()` — `forms.js:156`
- `gebeAta()` — `ui.js:1464` (gebelik konusunda görev oluştur)
- `openTohDet()` — `ui.js:2159` (tohumlama detay modal)
- `tohumlama_kaydet(...)` — RPC, sperma stok düşer
- `tohumlama_sonuc_gebe(p_toh_id)` — RPC, 21./35. gün görevleri
- `dogum_kaydet(p_anne_id, ...)` — RPC, 14 görev trigger

**Risks:**
1. **3 write path mevcut:** 2'si RPC bypass ediyor (ARCHITECTURE.md'de belirtilen kritik borç)
2. **deneme_no saklı:** Ön taraf bu alanı görmediğinden, backend'de hesaplama
3. **State machine:** Gebe/Doğum Yaptı durumundan geri döndürülemiyor

**Refactor Plan:** Aşama 1 — 3 RPC'yi konsolide et (`tohumlama_sonuc_gebe`, `tohumlama_sonuc_bos`, `tohumlama_abort`)

---

### Domain 3: Doğum Kaydı ve Buzağı Takibi

**Ana Akış:** Doğum oluştur → Buzağı otomatik eklenir → 14 görev otomatik → Buzağı büyümesi

**GitNexus Bulgusu:**
- **Entering Point:** `submitBirth()` (`forms.js:105-153`)
- **Process:** `SubmitBirth → G (getAll) → emit:chip → gorevler yaratıl`

**İş Akışı Detayı:**
```
Doğum Formu (anne, doğum tarihi, buzağı cinsiyet, buzağı ağırlığı, küpe, baba)
  ↓ (rpc: dogum_kaydet)
RPC Effects:
  1. dogum tablosuna kayıt ekle
  2. Yeni hayvan "Buzağı" grubunda ekle
       - gruppe: "Süt İçen Buzağı"
       - padok: "Buzağı Padok"
       - anne: anne.id
       - baba: tohumlama.sperma veya manuel
  3. Anneye doğum sonrası ilaç görevleri (7 görev):
       - Doğum günü: Oksitosin + Ademin + Kalsiyum
       - 2., 11., 25. günler: PG
       - 53.-54. günler: Ademin/Yeldif
       - 58-63. gün: Kızgınlık takibi
  4. Buzağıya ilk gün bakım görevleri (6 görev):
       - Kolostrum (2 saat)
       - Göbek kordonu dezenfeksiyonu
       - Küpeleme
       - Ademin/Maya/Probiyotik
  5. tohumlama.sonuc = "Doğum Yaptı"
  6. islem_log: DOGUM_KAYDI

Buzağı Büyümesi (automatic):
  - 75 gün → Sütten Kesilmiş Buzağı (otomatik görev)
  - 180 gün → Düve (Küçük) veya Besi (cinsiyete göre)
  - 365 gün → Düve (Büyük) veya Besi
```

**Kritik Kodlar:**
- `submitBirth()` — `forms.js:105`
- `openCikis()` — `forms.js:440` (doğum sonuç kaydı, "doğum yaptı" işaretle)
- `dogum_kaydet(p_anne_id, ...)` — RPC, 14 görev trigger
- `buzz_takip` tablosu — orphan (kullanılmıyor, silinecek)

**Risks:**
1. Buzağı otomatik gruba alınırken yaş validasyonu → trigger ve RPC'de
2. 14 görevin hepsinin job queue'ya düşmesi → performance (milyonlarca satır olabilir)

---

### Domain 4: Süt Ölçümü ve Performans Takibi

**Durum:** MVP kapsamı DIŞI. Prototype var: `sutIcenler()` (forms.js:489)

**Not:** Sağmal (Laktasyonda) hayvanlar için günlük süt üretimi kaydı. Henüz RPC yok, sadece UI stub.

---

### Domain 5: Aşılama ve Tedavi (Klinik Modülü)

**Ana Akış:** Tedavi Vakaları → İlaç Ekleme → Stok Ledger Düşer

**GitNexus Bulgusu:**
- **Process:** `CaseGunEkleOnayla → IdbClearAndPut → G (getAll)`
- **RPC'ler:** `create_case`, `add_treatment_day`, `add_drug_administration`, `close_case`

**İş Akışı Detayı (Migration 022 sonrası — Yeni Sistem):**
```
Vaka Açma (diseases kontrollü listesi)
  ↓ (rpc: create_case)
  - hayvan seç
  - hastalık seç (diseases dropdown — free text YASAK)
  - notes (opsiyonel)
  ↓
Günlük Tedavi Ekle (gün otomatik artar)
  ↓ (rpc: add_treatment_day)
  - case_id
  - day_no trigger ile otomatik increment
  ↓
İlaç Ekleme (drugs kontrollü listesi)
  ↓ (rpc: add_drug_administration)
  - drug_id seç (drugs dropdown)
  - doz + unit (IM, IV, SC, PO, Topikal, Intrauterin)
  → Trigger: stok_hareket ledger INSERT (pozitif miktar)
  → guncel_stok = baslangic - SUM(miktar)
  ↓
Vaka Kapat (kapalı vakaya gün/ilaç eklenemez)
  ↓ (rpc: close_case)
  - status = 'closed'
  - islem_log: VAKA_KAPAT
```

**Legacy Sistem (hastalik_log — hala var, ama yeni vaka YAZMIOR):**
- `hastalik_kaydet()` — eski vaka sistemi
- `tedavi_ekle()` — eski tedavi sistemi
- Korunuyor, yeni kod yazılmıyor

**Kritik Kodlar:**
- `caseGunEkleOnayla()` — `ui.js:2822` (vaka gün ekleme onayı)
- `hstIlacSil()` — `forms.js:1253` (ilaç sil)
- `closeDisease()` — `forms.js:833` (vaka kapat)
- `create_case(...)`, `add_treatment_day(...)`, `add_drug_administration(...)` — RPC'ler

**Risks:**
1. **Drugs → Stok bağlantısı:** `drugs.stock_item_id` FK, NULL ise stok düşmez
2. **Eski sistem migration:** `hastalik_log` orphan veri var, cleanup gerekli
3. **Status validation:** Kapalı vakaya gün/ilaç eklenmesi frontend'de kontrol gerekli

---

### Domain 6: Görev Yönetimi

**Ana Akış:** Otomatik Görev Üretim → Kategori Filtreleme → Tamamlama → Renk Mantığı

**GitNexus Bulgusu:**
- **Entering Point:** `loadTasks()` (`ui.js:354-407`)
- **Process:** `LoadTasks → renderTask → state filter → filterA → emit:chip`

**İş Akışı Detayı:**
```
Otomatik Görev Üretimi (RPC trigger'lar tarafından):
  1. Tohumlama 21./35. gün → Gebelik kontrolü görevleri
  2. Doğum → 7 annelik görev + 6 buzağı bakım görevı
  3. Aşılama → protokol görevleri
  4. Kızgınlık → tohumlama hatırlatma (55 gün sonra)

Görev Kategorileri:
  - TEDAVI (mor): tedavi uygulama
  - BAKIM (turuncu): genel bakım
  - DİĞER (gri): raporlama vb.

Görev Durumları:
  - Bekliyor (kırmızı): tarih yaklaştı
  - Devam Ediyor (mavi): tamamlama başladı
  - Tamamlandı (yeşil): yapıldı

Tamamlama Akışı:
  1. doneTask() — gorev_log.tamamlandi = NOW + notes
  2. Trigger: islem_log kaydı ("GOREV_TAMAM")
  3. renderTask() — durumu güncelle
  4. Gecikmiş görevler → updateKizginlikAlert() ile uyarı
```

**Kritik Kodlar:**
- `loadTasks()` — `ui.js:354` (görevleri filter'le ve render et)
- `renderTask()` — `ui.js:408` (tek görev HTML)
- `doneTask()` — `ui.js:475` (görev tamamla RPC)
- `decisions()` — `forms.js` başında, kategori koşulları (zincir if)

**Renk Mantığı:**
- Kızgınlık Badge: `kizginlik_uyari_badge` — 55 gün sonra kırmızı
- Tekrar Aşım Badge: `tekrar_asim_uyari_badge` — aşı sesi geçince uyarı
- Görev Renkleri: Kategori → CSS class

**Risks:**
1. **Otomatik trigger'lar:** Milyonlarca görev üretilebilir (DoS risk)
2. **Filtreleme logic:** `loadTasks(_curTaskFilter)` UI'da filter, DB'de DEĞİL → büyük datada slow

---

### Domain 7: Sürü Yönetimi (Filtreleme ve Gruplandırma)

**Ana Akış:** Sürü Listesi → Filtre (grup, padok, durum) → Detay Modal → Güncelleme

**GitNexus Bulgusu:**
- **Process:** `FilterA → G (GetAll) → Chip → ShowGebe`

**İş Akışı Detayı:**
```
Ana Sürü Sayfası:
  1. loadDash() → İstatistik (toplam, gebe, hasta, vb.)
  2. filterA() → 41 satır, Sürüyü grupo göre filtrele
  3. Chip'ler: Her hayvan bir badge
     - Gebe: "🤰"
     - Hasta: "🚨"
     - Kızgın: "💫"
     - Tedavi: "💉"

Detay Modal (openDet):
  1. Hayvan kart bilgileri (küpe, irk, yaş, düve/inek, grup)
  2. Tohumlama geçmişi (son 5 kayıt)
  3. Doğum geçmişi
  4. Görev listesi (açık görevler)
  5. Not ekle

Grup Yönetimi (GRUP_PADOK):
  - Sağmal (Laktasyonda) → Sağmal Padok
  - Gebe → Gebe Padok
  - Buzağı → Buzağı Padok
  - Besi → Besi Padok (Erkek/Dişi)
```

**Kritik Kodlar:**
- `filterA()` — `ui.js:694` (sürü filtreleme, 41 satır)
- `showGebe()` → chip render
- `loadDash()` — `ui.js:1-73` (istatistik yükleme)
- `_dashStatRow()` — `ui.js:74` (single stat satırı)

---

### Domain 8: Rapor ve Dashboard

**Ana Akış:** İstatistikler → Grafik Veriler → Export (future)

**Durum:** MVP kapsamı DIŞI. Stub var: `loadRaporlar()` (app.js:140)

**Planned:**
- Gebelik oranı grafikleri
- Süt verim trendi
- Ölüm/satış oranı
- Maliyeti-lir vs gelir

---

### Domain 9: Bildirim Sistemi

**Ana Akış:** Otomatik Bildirim → Kullanıcı Onayı → Kuyruğa Gir

**GitNexus Bulgusu:**
- **Entering Point:** `bildirimAc()` (`ui.js:4423`)
- **Process:** `BildirimAc → GetAll → emit:chip`

**İş Akışı Detayı:**
```
Bildirim Türleri:
  1. Kızgınlık Uyarısı (55 gün sonra) — otomatik
  2. Gebelik Kontrolü (21./35. gün) → görev
  3. Tedavi Görevleri → görev
  4. Aşılama Hatırlatma → görev

Bildirim Kaydı:
  1. bildirim_log tablosuna INSERT
  2. Frontend: localStorage bildirim permissioni
  3. Browser notification API (Web Push)

Kuyruk Temizleme:
  - Tamamlanan görevler → bildirim arşivi
  - kuyrugu-temizle handler
```

**Kritik Kodlar:**
- `bildirimAc()` — `ui.js:4423`
- `bildirimIzniAl()` — `ui.js:4385` (bildirim permission)
- `bildirimKontrol()` — `ui.js:4394` (bildirim kontrol)
- `updateBildirimBadge()` — `app.js:137`

---

### Domain 10: Stok Yönetimi

**Ana Akış:** Stok Giriş → Ledger Kaydı → Aktu

al Miktar Hesaplaması → Uyarı

**İş Akışı Detayı:**
```
Stok Ledger (Immutable):
  - Her hareket: stok_hareket tablosuna INSERT
  - Hiç DELETE/IPTAL yok
  - guncel_stok = baslangic_miktar - SUM(stok_hareket.miktar WHERE NOT iptal)

Giriş (negatif miktar):
  - İlaç/malzeme temin
  - stok_hareket.miktar < 0 → stok artar

Kullanım (pozitif miktar):
  - Tedavi veya aşılama → ilaç kullanımı
  - Stok trigger ile otomatik düşer
  - stok_hareket.miktar > 0 → stok düşer

Kritik Eşik Uyarısı:
  - Stok < minimum → uyarı toast
  - loadStokList() render
```

**Kritik Kodlar:**
- `loadStokList()` — `app.js:140` (stok yükleme)
- `stok_tuketim_view` — DB view (güncel miktar hesaplaması)

---

## 3. Kritik Fonksiyonlar (360° Görünüm)

### Fonksiyon 1: `loadTasks()`

**Konum:** `js/ui.js:354-407` (54 satır)

**Sorumluluk:** Görevleri filter'le ve render et

**Callers (Gelen Çağrılar):**
- `tasks-today` handler → `loadTasks('today')`
- `tasks-late` handler → `loadTasks('late')`
- `tasks-all` handler → `loadTasks('all')`
- `tasks-done` handler → `loadTasks('done')`

**Callees (Çağırdığı Fonksiyonlar):**
1. `getState('animals')` — state.js, hayvanlar listesi
2. `idbGetAll('gorev_log')` — api.js, IndexedDB okuma
3. `pullTables(['gorev_log', 'hayvanlar'])` — api.js, Supabase çek
4. `renderTask()` — ui.js:408, her görev HTML'sini render et
5. `fmtTarih()` — helpers.js, tarih format

**Process Katılım:**
- Proc_52: DoneTask → GetAll
- Proc_53: DoneTask → _trErr
- Proc_127: DoneTask → IdbPut

**Code Pattern:**
```javascript
async function loadTasks(filter = 'today') {
  _curTaskFilter = filter;
  let tasks = [];
  
  // IndexedDB'den veri çek
  const local = await idbGetAll('gorev_log');
  if (local && local.length) {
    tasks = local.filter(t => filterTaskByDate(t, filter));
  } else {
    // Fallback: Supabase'den çek
    await pullTables(['gorev_log', 'hayvanlar']);
    tasks = getState('tasks') || [];
  }
  
  // HTML render
  const html = tasks.map(t => renderTask(t)).join('');
  g('tasks_container').innerHTML = html;
}
```

**Risks:**
1. **Sync Delay:** IDB boşsa network beklenir (async, blok yok ama data stale olabilir)
2. **Memory:** 10K+ görev listesi → browser çökmesi riski (pagination gerekli)
3. **Filter Logic:** Frontend'de date range hisabı → timezone bugs

---

### Fonksiyon 2: `rpcOptimistic()`

**Konum:** `js/api.js:372-392` (21 satır)

**Sorumluluk:** RPC çağrı + otomatik state refresh + optimistic UI update

**Pattern:**
```javascript
async function rpcOptimistic(name, params = {}, { onSuccess, onError, successMsg } = {}) {
  if (!navigator.onLine) {
    toast('İnternet bağlantısı gerekli', true);
    throw new Error('Offline');
  }
  
  try {
    // 1. RPC çağrısı gönder
    const data = await rpc(name, params);
    
    // 2. Başarılı toast
    if (successMsg) toast(successMsg);
    
    // 3. Arka planda ilgili tabloları refresh (non-blocking)
    const tables = RPC_TABLES[name] || [];
    if (tables.length) {
      pullTables(tables).then(renderSafe).catch(console.warn);
    }
    
    // 4. Custom callback
    if (onSuccess) onSuccess(data);
    return data;
  } catch (e) {
    // Hata handle
    if (onError) onError(e);
    else toast('❌ ' + getUserMessage(e), true);
    throw e;
  }
}
```

**Callers:**
- `submitAnimal()` → `rpcOptimistic("hayvan_ekle", ...)`
- `submitInsem()` → `rpcOptimistic("tohumlama_kaydet", ...)`
- `submitBirth()` → `rpcOptimistic("dogum_kaydet", ...)`
- Tüm submit fonksiyonları

**Design Pattern: "Fire and Forget"**
1. UI'ı hemen update et (optimistic)
2. RPC gönder (arka planda)
3. Başarılı olursa state refresh
4. Hata olursa toast göster

**Risks:**
1. **Race Condition:** Birden fazla rpc aynı anda → last-write-wins
2. **RPC_TABLES:** İlişkisiz tablo ref olursa cache miss
3. **Batch Size:** 1000+ satır pull → 60ms debounce yeterli mi?

---

### Fonksiyon 3: `initApp()`

**Konum:** `js/app.js` (sayfa yükleme, init logic)

**Sorumluluk:** Uygulamayı başlat, event listener'ları ekle, ilk veri çek

**Startup Sequence:**
```javascript
// 1. Supabase bağlantı + IndexedDB init
window.addEventListener('load', async () => {
  await openDB('egesut_v9', 6);
  
  // 2. İlk veri çekme
  await pullTables([
    'hayvanlar', 'tohumlama', 'dogum', 'kizginlik_log',
    'gorev_log', 'stok', 'stok_hareket', 'bildirim_log'
  ]);
  
  // 3. AppState'e yazma
  setState('animals', data.hayvanlar);
  setState('stock', data.stok);
  
  // 4. Event delegation kuruluş (app.js:80+)
  document.addEventListener('click', handleGlobalClick);
  document.addEventListener('change', handleGlobalChange);
  
  // 5. Router kurulum
  window.addEventListener('popstate', routeChange);
  
  // 6. Otomatik sync başlat (5s interval)
  setInterval(syncNow, 5000);
  
  // 7. Page render
  showPage('dash');
});
```

**Callers:** Browser `load` event

**Callees:**
1. `openDB()` — IndexedDB init
2. `pullTables()` — api.js, Supabase'den veri çek
3. `setState()` — state.js, AppState yazma
4. `handleGlobalClick()` — ui.js, event handler
5. `syncNow()` — api.js, auto-sync loop
6. `showPage()` — ui.js, page render

**Process Timing:**
- App load: ~500ms (network bağlı)
- IndexedDB open: ~50ms
- First pull: ~200-500ms
- UI render: ~100ms
- **Total:** ~1s

**Risks:**
1. **Slow Network:** Blok yok ama UI boş kalabilir
2. **No Service Worker:** Offline'da stale data sadece IDB'den
3. **Polling Loop:** `setInterval(syncNow, 5000)` → future Realtime geçişi

---

### Fonksiyon 4: `State Management — AppState`

**Konum:** `js/state.js:3-89`

**Tasarım:** Simple EventEmitter pattern

```javascript
class AppState {
  constructor() {
    this._state = {
      animals: [],
      stock: [],
      currentPage: 'dash',
      gebeIds: new Set(),
      // ... 10+ daha
    };
    this._listeners = {}; // event → [callbacks]
  }

  get(key) { return this._state[key]; }
  set(key, value) {
    const old = this._state[key];
    if (old === value) return; // prevent loop
    this._state[key] = value;
    this.emit(key, value, old); // subscribers notify
  }

  on(event, callback) {
    if (!this._listeners[event]) this._listeners[event] = [];
    this._listeners[event].push(callback);
    // Immediate call with current value
    if (event !== '*') callback(this._state[event]);
    return () => this.off(event, callback); // unsub func
  }
}

const AppStateInstance = new AppState();
globalThis.__state = AppStateInstance;

function getState(key) { return globalThis.__state.get(key); }
function setState(key, value) { return globalThis.__state.set(key, value); }
```

**Usage:**
```javascript
// Write
setState('animals', newList);

// Read
const animals = getState('animals');

// Subscribe
state.on('animals', (newAnimals) => {
  renderAnimalList(newAnimals);
});
```

**Parallel Legacy:**
- `window._appState` — eski uyumluluk (kural: yeni kod yazmaz)
- `window._TH` — tohumlama hayvanları performans cache
- `window._curPg` — current page (state'e milenmeye başlandı)

**Migration:**
- Aşama 1.1'de başlandı (ReFactorRoadmap.md)
- 13 global hala `app.js:81`'de (refactor devam)
- Hedef: 2026-06-01 kadar tamamlanmak

---

## 4. Mimari Kararlar (ADR'ler)

### ADR-001: Vanilla JS, Framework Yok

**Karar:** Hiçbir frontend framework yok (React, Vue, Angular). Tek `index.html` + 6 JS modülü.

**Sebep:**
- Bundle yok → GitHub Pages instant deploy
- Learning curve düşük (veteriner için)
- Simple DOM manipulation yeterli

**Trade-off:** Manual event delegation, state sync challenging

---

### ADR-002: Controlled Entities (FK Zorunlu)

**Karar:** `diseases`, `drugs`, `hayvan` asla free text. FK **zorunlu**.

**Implementasyon:**
- UI: Dropdown (DB'den populate)
- Backend: RPC parametresi validation
- Sonuç: Data quality ✅, inconsistency ❌

---

### ADR-003: Stok Ledger Immutable

**Karar:** `stok_hareket` hiçbir zaman silinemez veya `iptal=true` yapılamaz.

**Kural:** Her düzeltme = yeni INSERT
```sql
-- YANLIŞ ❌
DELETE FROM stok_hareket WHERE id = x;

-- DOĞRU ✅
INSERT INTO stok_hareket (stok_id, miktar, ...) VALUES (..., -X, ...); -- geri alma
```

**Sebep:** Audit trail, legal compliance, financial reconciliation

---

### ADR-004: RPC'ler SECURITY DEFINER

**Karar:** Tüm yazma işlemleri backend RPC'ler üzerinden, SECURITY DEFINER.

**Sebep:**
- RLS policy'leri bypass (operatör → admin yetki)
- Business logic centralization
- Offline queue'dan recovery

---

### ADR-005: Frontend İş Mantığı Yok

**Prensip:** "Frontend sadece render ve input toplar, hesap yapmaz."

**Exception:** Tohumlama modülü (3 write path, RPC bypass) — kritik borç

---

### ADR-006: Agent Telsiz Mimarisi (2026-05-17)

**Karar:** Daemon yerine per-task agent spawn.

**Sebep:**
- PRoot Tokio crash (io_uring syscall)
- Per-task → fresh context → isolate crash
- Goose foreground process, exit sonrası MCP free

**Sonuç:** `goose_start(recipe, session_id, params)` → worker başlat

---

### ADR-007: Multi-Tier Goose Orchestration (2026-05-18)

**Karar:** Claude (Tier 0) → Goose Orchestrator (Tier 1) → Workers (Tier 2)

```
Claude (1) → Max 3 Orchestrators → Max 3 Workers Each → 9 Total
```

**Benefits:**
- Claude sadece karar alır
- Goose orta yönetim (plan + worker spawn)
- Per-task fresh context, no context window pollution

**Telsiz:** 3 MCP tool (agent_register, agent_send, agent_receive)

---

### ADR-008: İş Mantığı DB'de (Migration Kataloğu)

**Karar:** 30+ migration dosyası, 40+ RPC, 20+ trigger. Backend-heavy.

**Dosya:** `99999999999999_ground_truth.sql` (7576 satır)

**Sebep:**
- Supabase SECURITY DEFINER RPC → role separation
- Business logic centralization
- Trigger → otomatik görev / state transition

---

## 5. Refactor Yol Haritası (ReFactorRoadmap.md)

### Aşama 1 — Altyapı Tamamlama (Kısmen ✅)

| 1.1 | Global State → AppState | ⚠️ 13 global hala app.js:81 | Devam |
| 1.2 | Sabitler → config.js | ✅ Tamamlandı | DONE |
| 1.3 | Yardımcılar → utils/ | ✅ helpers.js + modal.js | DONE |
| 1.4 | Autocomplete tekilleştir | ⚠️ setupAutocomplete() var, test gerekli | Review |

### Aşama 2 — Veri Yönetimi ✅ (Review Gerekli)

- insertOffline / updateOffline
- IndexedDB index'leri (gorev_log, tohumlama)
- rpcOptimistic (zaten vardı)

### Aşama 3 — UI/Render (Risky — Bekliyor)

- ~150 event handler → delegation
- innerHTML → insertAdjacentHTML (büyük lister)
- Pagination / virtual scroll (Sürü 10K hayvan)

### Aşama 4 — Hata Yönetimi ✅ (Review Gerekli)

- errorHandler.js: withErrorHandling(), getUserMessage()
- Global error listeners

### Aşama 5 — Migration Cleanup ✅ (Review Gerekli)

- Ground truth creation
- Migration idempotency check
- Drop orphan objects (buzagi_takip, hastalik_log.ilac_stok_id)

### Aşama 6 — Güvenlik/XSS ✅ DONE (2026-05-23)

- ✅ esc() 9 innerHTML noktasına uygulandı
- ✅ esc() literal bug düzeltildi (app.js:604)
- innerHTML → textContent patterns (devam edebilir)

### Aşama 7 — Performans ✅

- Debounce / throttle

### Aşama 8 — Test/Kod Kalitesi ✅

- ESLint / Prettier
- JSDoc yorumları

### Aşama 9 — Dokümantasyon ✅

- README, CONTRIBUTING

**Progress Summary:**
- ✅ Tamamlandı: 1.2, 1.3, 2, 4, 5, 7, 8, 9
- ⚠️ Devam eden: 1.1 (13 global), 1.4 (autocomplete test)
- ⏸️ Risky (Postponed): 3 (event delegation ~150 handler)

**Next Steps:**
1. 1.1 global state migration tamamlanması (low-risk refactor)
2. 1.4 autocomplete test ve cleanup
3. 3. aşama event delegation (big-bang refactor, review öncesi plan gerekli)

---

## 6. Fonksiyonel Kümeler (GitNexus Clusters)

GitNexus analizi 274 execution flow'u **9 ana cluster**'a gruplayacak:

1. **Hayvan Yönetimi:** submitAnimal, filterA, openDet, hayvan_ekle RPC
2. **Tohumlama:** submitInsem, gebeAta, tohumlama_kaydet, tohumlama_sonuc_gebe
3. **Doğum:** submitBirth, dogum_kaydet, 14-görev-trigger
4. **Görev Sistemi:** loadTasks, doneTask, renderTask, kategori filter
5. **Klinik:** create_case, add_treatment_day, add_drug_administration
6. **Stok:** loadStokList, stok_ledger, kritik-eşik-uyarı
7. **Sürü Filtresi:** filterA, sürü-listesi, chip-render, ShowGebe
8. **Bildirim:** bildirimAc, bildirimKontrol, updateBildirimBadge
9. **State/Sync:** AppState, pullTables, renderSafe, syncNow

---

## 7. Teknoloji Stack Özeti

| Katman | Teknoloji | Version/Framework |
|--------|-----------|------------------|
| **Frontend** | Vanilla JS | ES6+ (no build) |
| **HTML/CSS** | Single index.html | CSS Grid + Flexbox |
| **State** | AppState (EventEmitter) | Custom (state.js) |
| **HTTP** | Supabase REST + RPC | @supabase/supabase-js |
| **Cache** | IndexedDB | egesut_v9 (ver=6) |
| **Backend** | PostgreSQL + Supabase | pg_trgm, uuid, JSONB |
| **Deploy** | GitHub Pages | GitHub Actions CI/CD |
| **Testing** | Playwright E2E | Smoke tests (GitHub Actions) |
| **Development** | VS Code + Termux | Windows + Android |

---

## 8. Kritik Teknik Borç

| İssue | Önem | Aşama | Not |
|-------|------|-------|-----|
| Tohumlama: 3 write path | 🔴 | 1 (next) | RPC refaktörü |
| Global state migration | 🔴 | 1 | 13 global hala app.js:81 |
| Event delegation | 🟡 | 3 | ~150 handler, big-bang refactor |
| Orphan veri (buzagi_takip) | 🟢 | 5 | Migration drop |
| Polling → Realtime | 🟡 | 5+ | Future: Supabase Realtime |
| Permission model | 🟠 | Future | Çoklu kullanıcı desteği |

---

## 9. Deployment ve CI/CD

**GitHub Actions Pipeline:**
```
git push → GitHub Actions
  ├─ ESLint check
  ├─ Playwright E2E (smoke.spec.js)
  ├─ supabase db push (migration yükle)
  └─ GitHub Pages deploy (index.html serve)
```

**URL'ler:**
- Live: https://meliksahtokur.github.io/egesut-erp1/
- Supabase: https://zqnexqbdfvbhlxzelzju.supabase.co
- Repo: github.com/Meliksahtokur/egesut-erp1

---

## 10. Sonuç ve Öneriler

### Mimari Güçlü Yönleri ✅

1. **Clear Separation:** UI (render) ↔ App (state) ↔ DB (logic)
2. **Immutable Audit:** Stok ledger, islem_log → financial compliance
3. **State Centralization:** AppState → future reactivity
4. **RPC Security:** SECURITY DEFINER → operator bypass RLS
5. **Fresh Context:** Per-task agent spawn → crash isolation

### Şu Anda Yapılan Iyileştirmeler

1. ✅ Aşama 1-2-4-5-7-8-9 code-complete (review pending)
2. ✅ GitNexus index fresh (3173 sembol, 274 flow)
3. ⚠️ 1.1 (13 global) + 1.4 (autocomplete) devam
4. ⏸️ Aşama 3 (event delegation) risky, later

### Immediate Next

1. **Critical:** Aşama 1.1 global state migration (low-risk, high-impact)
2. **Medium:** 1.4 autocomplete cleanup + test
3. **Planning:** Aşama 3 event delegation (plan + review cycle gerekli)
4. **Research:** Realtime migration (goose-ops ile orchestrate et)

### MVP Ready?

**✅ YES** — Sürü, Üreme, Görev, Stok domains production ready. Klinik 90% hazır (UI finalize gerekli).

**Timeline:** 2026-06-01 full MVP (tüm 5 domain production).

---

**Analiz Tarihi:** 2026-05-23  
**GitNexus Index:** egesut-erp1 (3173 symbols, 274 flows, 5572 relationships)  
**Next Review:** 2026-06-01 (Aşama 3 planı sonrası)
