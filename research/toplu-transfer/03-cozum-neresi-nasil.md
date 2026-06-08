# Toplu Transfer Çözümü: Nereye, Nasıl

**Tarih:** 2026-06-02
**Durum:** Öneri
**Kapsam:** UI/UX tasarımı + implementasyon planı

---

## 1. Mevcut Durumun Kritik Analizi

### 1.1 Altyapı Çalışıyor Ama Saklı

Backend'de `padok_degistir_toplu` RPC'si çalışır durumda ve transactional. Frontend'de `padokTopluTasi()` + `padokTransferOnayla()` fonksiyonları mevcut. Ama kullanıcı bu özelliğe **sadece şu yoldan** ulaşabiliyor:

```
1. Bir padok kartına tıkla → m-padok-det (modal 1)
2. Hayvan listesinde checkbox'ları işaretle
3. "📦 Seçilenleri Taşı" butonu → m-padok-transfer (modal 2)
4. Dropdown'dan hedef seç → "✅ Taşı"
```

Bu **3 katmanlı modal akışı** kullanılabilirliği düşürüyor. Ayrıca:
- **Cross-padok seçim yok** — sadece bir padok içinden seçim
- **Kapasite kontrolü yok**
- **Grup uyum filtresi yok**
- **Sürü listesinden toplu işlem yok**

### 1.2 Mevcut Pattern'ler

Toplu aşı (`m-bulk-vaccine`) ve toplu ilaç (`m-bulk-ilac`) modal'ları **tab-based** bir pattern kullanıyor:

| Tab | Açıklama |
|-----|----------|
| Padok | Bir padok seç → içindeki hayvanları getir |
| Filtre | Kriter bazlı (durum, yaş aralığı) |
| Serbest Seçim | Arama + checkbox ile manuel seçim |

Bu pattern **toplu transfer için de kullanılabilir** — hatta transfer, toplu aşıdan daha basit çünkü aşıda aşı seçimi, doz, tarih gibi ek alanlar var. Transferde sadece **hedef padok** seçimi yeterli.

---

## 2. Önerilen Çözüm: 3 Giriş Noktası

### 2.1 Giriş Noktası A — Sürü Listesinden Seçim + Taşı (PRIMARY)

**En yüksek etkili değişiklik.** Kullanıcı sürü listesindeyken hayvanları seçip doğrudan taşıyabilir.

```
Sürü Görünümü
├── Search bar yanına [🔀 Toplu Taşı] butonu
├── Seçim modu active edilince:
│   ├── Her animal-card'a checkbox overlay'i eklenir
│   ├── Bottom action bar belirir: "5 hayvan seçildi [Taşı] [İptal]"
│   └── Padok filtresi aktifken sadece filtrelenen padoktaki hayvanlar seçilebilir
└── "Taşı" tıklanınca → m-bulk-transfer modal'ı açılır
```

**Dosya değişiklikleri:**
- `index.html`: Sürü toolbar'ına buton + action bar HTML + yeni modal
- `js/ui.js`: Seçim modu state'i, render fonksiyonları, event handler'lar
- `js/utils/handlers.js`: Yeni aksiyon kayıtları

### 2.2 Giriş Noktası B — Padok Detay İçinden (MEVCUT + İYİLEŞTİRİLMİŞ)

Mevcut `m-padok-det` → `m-padok-transfer` akışı korunur ama iyileştirilir:

1. **Tek modal**: Transfer işlemi `m-padok-det` içinde inline yapılır (dropdown aynı modalda belirir)
2. **Kapasite göstergesi**: Her padok için `(X/Y dolu)` bilgisi
3. **Grup filtresi**: Seçili hayvanların grubuna uygun olmayan padoklar gri/gizli

### 2.3 Giriş Noktası C — Dashboard'dan Kısayol

Dashboard'da "Aktif Hayvan" kartına `[🔀 Toplu Taşı]` butonu eklenir — doğrudan `m-bulk-transfer` modal'ını açar (hayvan seçimi yapılmamış halde, padok tab'ı active).

---

## 3. Yeni Modal Bileşeni: `m-bulk-transfer`

### 3.1 Modal Yapısı

Mevcut `m-bulk-vaccine` pattern'ini takip eder ama transfer için optimize edilir:

```
┌─────────────────────────────────────────────┐
│ ─── (m-handle)                              │
│ 🔀 Toplu Padok Değişimi                [×]  │
│                                              │
│ [Padok] [Filtre] [Serbest Seçim]            │
│                                              │
│ ┌─ PADOK TAB (default active) ─────────────┐│
│ │ ▼ Kaynak Padok [___________]             ││
│ │   🔍 Hayvanları Getir (3)                ││
│ └───────────────────────────────────────────┘│
│                                              │
│ ┌─ SEÇİLİ HAYVANLAR ───────────────────────┐│
│ │ 🐄 12345 · Sağmal · 3y 2a          [×]  ││
│ │ 🐄 12346 · Sağmal · 4y 1a          [×]  ││
│ │ 🐄 12347 · Kuru/Gebe · 2y 5a       [×]  ││
│ │ ...                                      ││
│ │ Toplam: 3 hayvan                         ││
│ └───────────────────────────────────────────┘│
│                                              │
│ ┌─ HEDEF PADOK ────────────────────────────┐│
│ │ ▼ Kuru/Gebe Padok (12/20) ████████░░░   ││
│ │                                           ││
│ │ Önerilen Padoklar (grup uyumu):          ││
│ │ ✅ Kuru/Gebe Padok    12/20  %60         ││
│ │ ⚡ Düve Padok (Büyük)   5/15  %33        ││
│ │ ❌ Sağmal Padok       20/20  DOLU        ││
│ └───────────────────────────────────────────┘│
│                                              │
│ ┌─ İŞLEM ÖZETİ ────────────────────────────┐│
│ │ 3 hayvan → Sağmal Padok                  ││
│ │         → Kuru/Gebe Padok                ││
│ │ Kapasite: ✓ Uygun (12/20)                ││
│ │ Grup:     ✓ Uyumlu                       ││
│ └───────────────────────────────────────────┘│
│                                              │
│ [🔀 3 Hayvanı Taşı] (btn-g, full width)     │
│ [İptal] (btn-o)                              │
 ──────────────────────────────────────────────┘
```

### 3.2 State Yönetimi

```javascript
// Yeni global state değişkenleri (ui.js)
let _btSecimModu = false;          // Sürü seçim modu aktif mi?
let _btSecilenIds = [];            // Seçili hayvan ID'leri (cross-padok)
let _btKaynakPadokId = null;       // Kaynak padok (tek padok seçiliyse)
let _btHedefPadokId = null;        // Seçilen hedef padok

// Mevcut değişkenlerle uyum
// _pdHayvanIds → padok detay içi seçim (korunur)
// _pdTransferHayvanIds → onay bekleyen (korunur)
// _pdKaynakPadokId → kaynak padok (korunur)
```

### 3.3 UX Akışı

```
Giriş Noktası A (Sürü):
  [🔀 Toplu Taşı] tıkla
    → _btSecimModu = true
    → Her animal-card'a checkbox + "Seçim Modu" banner'ı
    → Bottom action bar belirir: "0 hayvan seçildi [Taşı] [İptal]"
    → Kullanıcı hayvanları tek tek seçer (farklı padoklardan olabilir)
    → _btSecilenIds güncellenir
    → [Taşı] tıkla → openM('m-bulk-transfer')
    → _btSecimModu = false, görünüm normale döner

Giriş Noktası B (Padok Detay):
  Mevcut checkbox + "📦 Seçilenleri Taşı" akışı
    → _pdTransferHayvanIds → _btSecilenIds'e kopyalanır
    → openM('m-bulk-transfer') (yeni modal, eski m-padok-transfer değil)

Giriş Noktası C (Dashboard):
  Dashboard'daki [🔀 Toplu Taşı]
    → openM('m-bulk-transfer') direkt
    → Padok tab'ı active, kullanıcı padok seçip hayvanları getirir
```

---

## 4. Modal Tab'larının Detayı

### 4.1 Tab: Padok (default)

Mevcut `m-bulk-vaccine`'deki "Padok" tab'ının aynısı:

1. `select#bt-padok` — kaynak padok seç
2. `[🔍 Hayvanları Getir]` butonu — padoktaki aktif hayvanları listeler
3. Hayvan listesi checkbox'lı olarak `#bt-hayvan-listesi`'nde render edilir

### 4.2 Tab: Filtre

Kriter bazlı hayvan seçimi — toplu aşıdaki pattern'den daha basit:

- **Grup filtresi**: `select#bt-f-grup` — "Sağmal (Laktasyonda)", "Gebe Düve", etc.
- **Cinsiyet**: Dişi / Erkek / Tümü
- **Yaş aralığı**: min/max ay input'ları
- **`[Filtrele]`** butonu → sonuçları `#bt-hayvan-listesi`'nde göster

Her hayvanın yanında checkbox — kullanıcı filtrelenmiş listeden seçim yapar.

### 4.3 Tab: Serbest Seçim

Arama kutusu + tüm hayvanları getir:

1. `input#bt-s-ara` — küpe/ID arama
2. `#bt-s-list` — scrollable checkbox list (tüm aktif hayvanlar)
3. Sayaç: "X hayvan seçildi"

---

## 5. Kapasite + Grup Uyum Göstergeleri

### 5.1 Kapasite Göstergesi

Her padok seçeneğinde `(X/Y dolu)` formatında gösterim:

```javascript
// ui.js'ye eklenecek yardımcı fonksiyon
function _padokKapasiteHtml(padok, hayvanSayisi) {
  const kap = padok.kapasite;
  if (!kap) return ''; // kapasite tanımlanmamış
  const dolu = hayvanSayisi;
  const yuzde = Math.round((dolu / kap) * 100);
  const sinif = yuzde >= 100 ? 'dolu' : yuzde >= 80 ? 'uyari' : 'uygun';
  return `<span class="pk-${sinif}">${dolu}/${kap} (${yuzde}%)</span>`;
}
```

CSS stilleri:
```css
.pk-uygun { color: var(--green); }
.pk-uyari { color: var(--amber); }
.pk-dolu { color: var(--red); font-weight: 700; }
```

### 5.2 Grup Uyum Filtresi

`_pdTransferAcSelector()`'daki mantık genişletilir:

```javascript
function _btUygunPadoklar(padoklar, hayvanlar) {
  const gruplar = [...new Set(hayvanlar.map(h => h.grup))];
  return padoklar.map(p => {
    const uygun = gruplar.every(g => {
      const uygunAdlar = GRUP_PADOK[g] || [];
      return uygunAdlar.length === 0 || uygunAdlar.includes(p.ad);
    });
    return { ...p, uygun };
  });
}
```

Uygun olmayan padoklar:
- Dropdown'da `disabled` + `(Bu grup için uygun değil)` notu
- Grid görünümünde gri + çizgili

---

## 6. Değişecek Dosyalar (Kesin Liste)

| Dosya | Değişiklik | Satır |
|-------|-----------|-------|
| `index.html` | Sürü toolbar'ına `[🔀 Toplu Taşı]` butonu + selection mode banner HTML | ~355 |
| `index.html` | Bottom action bar HTML (sürü listesi altına fixed) | ~386 |
| `index.html` | Yeni `m-bulk-transfer` modal'ı (tab-based, mevcut bulk vaccine pattern'inde) | ~1796 (sonra) |
| `index.html` | Eski `m-padok-transfer` modal'ını koru (opsiyonel) veya kaldır | ~1782 |
| `js/ui.js` | `_bt*` global state değişkenleri | ~5452 |
| `js/ui.js` | `enterBulkSelectMode()` / `exitBulkSelectMode()` | yeni |
| `js/ui.js` | Sürü animal-card'larına checkbox ekleme (seçim modundayken) | ~629 |
| `js/ui.js` | `_btSecimiGuncelle()` — seçim sayacı + action bar update | yeni |
| `js/ui.js` | `openBulkTransfer()` — modal açma + state transfer | yeni |
| `js/ui.js` | `renderBtHayvanlar()` — modal içi hayvan listesi | yeni |
| `js/ui.js` | `_btKapasiteKontrol()` — kapasite validasyonu | yeni |
| `js/ui.js` | `_btGrupUygunluk()` — grup-padok uyum kontrolü | yeni |
| `js/ui.js` | `btTransferOnayla()` — onay + RPC çağrısı | yeni |
| `js/ui.js` | Mevcut `padokTopluTasi()`'ı yeni modala yönlendir | ~5524 |
| `js/utils/handlers.js` | `'bt-toggle-mode'`, `'bt-transfer'`, `'bt-close'` gibi yeni aksiyonlar | ~243 |
| `supabase/migrations/...` | Kapasite kontrolü ekle (RPC'ler) | opsiyonel |

---

## 7. Adım Adım Implementasyon

### Adım 1 — HTML: Sürü Toolbar'ı + Seçim Modu UI

`index.html` ~355 (search-bar yanına):

```html
<button id="bt-toggle-btn" class="btn btn-sm" 
        style="background:rgba(42,107,181,.12);color:var(--blue);border:1px solid rgba(42,107,181,.2);white-space:nowrap"
        data-action="bt-toggle-mode">🔀 Toplu Taşı</button>
```

`index.html` ~386 (suru-body öncesi):

```html
<div id="bt-action-bar" style="display:none;position:sticky;bottom:0;background:var(--card);border-top:2px solid var(--blue);padding:10px 12px;margin:0 -16px;margin-top:auto;z-index:10">
  <div style="display:flex;align-items:center;gap:10px">
    <span id="bt-count" style="font-weight:800;font-size:.85rem;color:var(--blue)">0 hayvan seçildi</span>
    <span id="bt-padok-count" style="font-size:.72rem;color:var(--ink3)">(0 padok)</span>
    <div style="flex:1"></div>
    <button class="btn btn-sm btn-b" data-action="bt-transfer" disabled>🔀 Taşı</button>
    <button class="btn btn-sm btn-o" data-action="bt-cancel" style="margin:0">İptal</button>
  </div>
</div>
```

### Adım 2 — HTML: Yeni Modal `m-bulk-transfer`

Tab-based (toplu aşı pattern'i), `m-padok-transfer`'in yerine veya yanına.

### Adım 3 — JS: Seçim Modu

```javascript
// ui.js'e eklenecek
let _btSecimModu = false;
let _btSecilenIds = [];
let _btActionBar = null;

function enterBulkSelectMode() {
  _btSecimModu = true;
  _btSecilenIds = [];
  document.getElementById('bt-toggle-btn').textContent = '✕ İptal';
  document.getElementById('bt-toggle-btn').style.borderColor = 'var(--red)';
  document.getElementById('bt-toggle-btn').style.color = 'var(--red)';
  document.getElementById('bt-action-bar').style.display = 'block';
  _renderBtCheckboxes();
}

function exitBulkSelectMode() {
  _btSecimModu = false;
  _btSecilenIds = [];
  document.getElementById('bt-toggle-btn').textContent = '🔀 Toplu Taşı';
  document.getElementById('bt-toggle-btn').style.borderColor = '';
  document.getElementById('bt-toggle-btn').style.color = '';
  document.getElementById('bt-action-bar').style.display = 'none';
  _clearBtCheckboxes();
}

function _renderBtCheckboxes() {
  // Her animal-card'ın başına checkbox ekle
  document.querySelectorAll('.animal-card').forEach(card => {
    if (card.querySelector('.bt-cb')) return;
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.className = 'bt-cb';
    cb.style.cssText = 'width:18px;height:18px;cursor:pointer;flex-shrink:0';
    cb.onchange = (e) => { e.stopPropagation(); _btToggleHayvan(card.dataset.id, cb.checked); };
    card.insertBefore(cb, card.firstChild);
    card.style.cursor = 'default';
    // onclick'i koru — checkbox'a tıklanınca açılmasın
  });
}
```

### Adım 4 — JS: Modal İçi Fonksiyonlar

`openBulkTransfer()`:
- `_btSecilenIds`'i al
- Modal içinde hayvan listesini render et
- Padok dropdown'larını doldur
- Kapasite + grup uygunluk hesapla

`btTransferOnayla()`:
- Validasyon (hedef seçilmiş mi, kapasite uygun mu)
- `rpc('padok_degistir_toplu', ...)` çağır
- Toast + refresh

### Adım 5 — Handler Kayıtları

```javascript
// handlers.js'e eklenecek
'bt-toggle-mode': () => _btSecimModu ? exitBulkSelectMode() : enterBulkSelectMode(),
'bt-transfer': () => { if (_btSecilenIds.length) openBulkTransfer(); },
'bt-cancel': () => exitBulkSelectMode(),
'bt-onay': () => btTransferOnayla(),
// Tab切换
'bt-tab-padok': () => _btSwitchTab('padok'),
'bt-tab-filtre': () => _btSwitchTab('filtre'),
'bt-tab-serbest': () => _btSwitchTab('serbest'),
```

---

## 8. Kullanıcı Deneyimi Karşılaştırması

| Özellik | Mevcut | Yeni |
|---------|--------|------|
| Cross-padok seçim | ❌ | ✅ Farklı padoklardan hayvan seçimi |
| Sürü listesinden seçim | ❌ | ✅ Animal-card'larda checkbox |
| Modal katmanı sayısı | 3 (det → transfer → onay) | 1 (tek bottom sheet) |
| Kapasite görme | Sadece ayarlar'da | Dropdown'da inline gösterim |
| Grup uyum filtresi | ❌ | ✅ Otomatik filtre + uyarı |
| Toplu seçim kriteri | ❌ | ✅ Filtre tab'ı ile (grup, yaş, cinsiyet) |
| İşlem özeti | ❌ | ✅ "3 hayvan → Kuru/Gebe" özet kartı |
| Hata yönetimi | Basit toast | Detaylı: "2 başarılı, 1 başarısız: ..." |

---

## 9. Öncelik Sırası

```
┌─────────────┬──────────────────────────────────┬──────────┐
│ Öncelik     │ Ne                               │ Süre     │
├─────────────┼──────────────────────────────────┼──────────┤
│ P0 (BUG)    │ RPC'lere kapasite kontrolü ekle  │ 30 dk    │
│ P1          │ Yeni m-bulk-transfer modal'ı     │ 2 saat   │
│ P2          │ Sürü seçim modu + action bar     │ 2 saat   │
│ P3          │ Filtre tab'ı (grup/yaş/cinsiyet) │ 1 saat   │
│ P4          │ Dashboard kısayolu               │ 15 dk    │
│ P5          │ Eski m-padok-transfer'i kaldır   │ 15 dk    │
└─────────────┴──────────────────────────────────┴──────────┘
```

---

## 10. Mevcut Kodla Uyum

**Kritik karar:** Mevcut `m-padok-det` içindeki checkboxes + `pdTopluTasi()` akışını **koru**, ama `_pdTransferAcSelector()` fonksiyonunu eski `m-padok-transfer` yerine **yeni `m-bulk-transfer` modal'ına yönlendir**.

Bu sayede:
- Padok detay içinden toplu taşıma çalışmaya devam eder
- Ama kullanıcı yeni, daha iyi bir UI görür
- İki kod yolu tek bir `openBulkTransfer()` fonksiyonunda birleşir

```javascript
// Mevcut padokTopluTasi() güncellemesi:
function padokTopluTasi() {
  if (!_pdHayvanIds.length) { toast('⚠️ Lütfen en az bir hayvan seçin', true); return; }
  _btSecilenIds = [..._pdHayvanIds];
  _btKaynakPadokId = _pdKaynakPadokId;
  openBulkTransfer(); // Yeni modal, eski m-padok-transfer değil
}
```

---

## 11. Tasarım Notları

### Renk Paleti (Mevcut Tema ile Uyumlu)

Mevcut tema zaten koyu yeşil/zeytin tonlarında:
- `--green: #4e9a2a` — ana aksiyon
- `--blue: #2a6bb5` — seçim modu
- `--amber: #e8900c` — uyarı (kapasite %80+)
- `--red: #c0321a` — dolu / hata
- `--card: #1a2015` — zemin

**Ek stiller:**
```css
/* Kapasite bar */
.pk-bar{height:4px;border-radius:2px;background:var(--card2);overflow:hidden}
.pk-fill{height:100%;border-radius:2px;transition:width .3s}
.pk-fill.uygun{background:var(--green)}
.pk-fill.uyari{background:var(--amber)}
.pk-fill.dolu{background:var(--red)}

/* Seçim modu banner */
.bt-banner{background:rgba(42,107,181,.1);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:6px 12px;font-size:.75rem;color:var(--blue);margin-bottom:8px}

/* Bottom action bar */
#bt-action-bar{animation:slideup .2s ease;box-shadow:0 -4px 20px rgba(0,0,0,.3)}

/* Seçili hayvan kartı highlight */
.animal-card.bt-selected{background:rgba(42,107,181,.08);border-left:3px solid var(--blue)}
```

### Responsive

- Bottom action bar: `position:sticky` ile sürü listesinin altında sabit
- Modal: mevcut `.mo` pattern'i zaten responsive (bottom sheet)
- Tab geçişleri: inline-flex, dar ekranda scrollable
