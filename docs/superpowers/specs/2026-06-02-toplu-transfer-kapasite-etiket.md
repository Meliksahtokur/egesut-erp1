# Toplu Padok Transfer + Kapasite Sistemi + Besi Etiket Akışı

**Tarih:** 2026-06-02  
**Durum:** Onaylandı — Implementation bekliyor  
**Kapsam:** A+B+C (D: Padok Yönetim Ekranı ayrı spec)

---

## 1. Özet

Sürü dashboardına toplu padok transfer özelliği eklenir. Kapasite uyarı sistemi devreye girer. Besi padoğuna uyumsuz grup transferinde etiket (kısır/satışta) zorunlu hale gelir. Padok doluluk widget sürü dashboardına eklenir.

**Kapsam dışı:** Padok ekleme/düzenleme/silme ekranı (D spec), kapasite değeri ayarlama UI'ı.

---

## 2. Veri Katmanı

### 2.1 DB Değişiklikleri

```sql
-- Etiket kolonu
ALTER TABLE hayvanlar ADD COLUMN etiketler text[] DEFAULT '{}';
-- Geçerli değerler: 'kisir', 'satista'

-- Index (etiket sorguları için)
CREATE INDEX idx_hayvanlar_etiketler ON hayvanlar USING GIN(etiketler);
```

### 2.2 `padok_degistir` RPC — Kapasite Kontrolü Eklenir

Mevcut imza korunur: `padok_degistir(p_hayvan_id text, p_yeni_padok_id uuid, p_not text)`

Yeni davranış:
- Kapasite %100 doluysa → `{ success: false, error: 'kapasite_dolu', detay: '20/20' }`
- Kapasite %80-99 → transfer yapılır + `{ success: true, kapasite_uyari: true, doluluk_yuzde: 85 }`
- Kapasite tanımsız (NULL) → kontrol yapılmaz, transfer geçer

### 2.3 `padok_degistir_toplu` RPC — Yeniden Yazılır

Mevcut per-animal exception loop kaldırılır. All-or-nothing transaction yapısına geçilir.

**Yeni imza:** `padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid, p_etiketler text[] DEFAULT NULL)`

**İşlem sırası:**
1. Hedef padok var mı?
2. Kapasite kontrolü: `COUNT(aktif hayvanlar) + array_length(p_hayvan_ids)` > kapasite → hard block
3. Her hayvan için: var mı? zaten bu padokta mı?
4. Tüm validasyonlar geçerse: toplu UPDATE + islem_log
5. Herhangi adımda hata → tüm transaction ROLLBACK

**Dönüş:**
```json
// Başarı
{ "success": true, "hayvan_sayisi": 3, "yeni_padok": "Kuru/Gebe Padok", "yeni_padok_id": "uuid", "kapasite_uyari": false }

// Hata — kapasite
{ "success": false, "error": "kapasite_dolu", "detay": "20/20" }

// Hata — grup (bilgi amaçlı, RPC block etmez — frontend block eder)
{ "success": false, "error": "validasyon", "mesaj": "..." }
```

**Not:** `p_etiketler` gönderilirse, transfer edilen hayvanlara `etiketler` kolonu güncellenir (mevcut etiketlerle birleştirilir, tekrar eklenmez).

---

## 3. Padok Doluluk Widget

### 3.1 Konum

Sürü dashboardında filter chips'in üzerinde, ayrı bir satır:

```
[🔍 Arama] [Padok Filtre▼] [🔀 Toplu Taşı]

── Padok Doluluk ──────────────────────────→ (yatay scroll)
[Sağmal 18/20 ████░░] [Kuru/Gebe 12/20 ██░░] [Düve(B) 5/15 █░░░]

[Tümü] [Dişi] [Erkek] | [Gebe] [Boş] | [Hasta]
──────────────────────────────────────────────────
🐄 Kart listesi...
```

### 3.2 Renk Kuralları

| Doluluk | Bar Rengi | Anlamı |
|---------|-----------|--------|
| < %80 | Yeşil (`--green`) | Normal |
| %80–99 | Sarı (`--amber`) | Dolmak üzere |
| %100 | Kırmızı (`--red`) | Dolu |
| Kapasite yok | Gri, bar yok | Tanımsız |

### 3.3 Davranış

- Chip'e tıkla → `[Padok Filtre▼]` dropdown'ı o padoğa set olur, sürü listesi filtrelenir
- Seçim modundayken chip tıklaması sadece filtreyi değiştirir, seçim korunur
- Veri kaynağı: `loadPadokConfig()` zaten padoklar + aktif hayvan sayısını çekiyor — yeniden kullanılır

### 3.4 HTML Yapısı

```html
<div id="padok-doluluk-bar" style="overflow-x:auto;white-space:nowrap;padding:4px 0 8px;display:flex;gap:6px">
  <!-- JS ile render edilir -->
</div>
```

---

## 4. Toplu Transfer Seçim Modu

### 4.1 Toolbar Değişikliği

```html
<!-- Mevcut toolbar'a eklenir -->
<button id="bt-toggle-btn" data-action="bt-toggle-mode">🔀 Toplu Taşı</button>
```

Seçim modu aktifken buton `✕ İptal` olur, kırmızıya döner.

### 4.2 Seçim Modu Davranışı

**Aktifken:**
- Her animal-card'a checkbox eklenir (opacity 0 → 1 transition)
- Kart tıklaması = seçim toggle (hayvan detayı açılmaz)
- Filtre/arama değişince seçim korunur
- Action bar animasyonla altta belirir

**Action Bar (fixed bottom):**
```
[N hayvan seçildi (M padok)]    [🔀 N Taşı]  [İptal]
```
- N = 0 → `[Taşı]` disabled
- Padok sayısı = kaç farklı kaynak padoktan seçildiği

### 4.3 Seçim Terk Uyarısı

Seçim modu aktifken herhangi başka işlem (sekme değişimi, modal açma) tetiklenirse:

```
"Seçimin kaybolacak, devam etmek istiyor musun?"
[Devam Et]  [İptal]
```

Devam → seçim sıfırla, işlemi yap.

### 4.4 State Değişkenleri (ui.js)

```javascript
let _btSecimModu = false;
let _btSecilenIds = [];        // cross-padok, filtreden bağımsız
```

---

## 5. m-bulk-transfer Modal

### 5.1 Yapı

Tab-based modal, mevcut `m-bulk-vaccine` pattern'ini takip eder.

**Tablar:**
- **📋 Padok:** Kaynak padok seç → hayvanları getir → listeye ekle
- **🎯 Filtre:** Grup + cinsiyet + yaş filtresi → listele → seç
- **✋ Serbest:** Küpe ara → checkbox seç

### 5.2 Hedef Padok Listesi

Her padok için doluluk bilgisi ve grup uyum durumu gösterilir:

| Durum | Gösterim |
|-------|---------|
| Uyumlu + < %80 | Yeşil, seçilebilir |
| Uyumlu + %80-99 | Sarı ⚠️, seçilebilir (uyarı gösterilir) |
| Uyumlu + %100 | Kırmızı 🔴, disabled |
| Grup uyumsuz (besi hariç) | ❌ disabled |
| Besi + uyumsuz grup | Seçilebilir → etiket akışı tetiklenir |

**Grup uyum kontrolü frontend'de yapılır** (`GRUP_PADOK` mapping'i kullanılarak).

### 5.3 Cross-Padok Uyumsuzluk

Seçili hayvanlar farklı gruplardan geliyorsa ve kesişim padoğu yoksa:

```
⚠️ Seçili hayvanlar için ortak uyumlu padok bulunamadı.
   Aynı gruptaki hayvanları seçin veya ayrı ayrı taşıyın.
```

`[Taşı]` butonu disabled kalır.

### 5.4 Özet Bölümü

Hedef padok seçilince özet gösterilir:
```
N hayvan → [Hedef Padok Adı]
Kapasite: ✓ X/Y (%Z)          ← sarı veya yeşil
Grup:     ✓ Uyumlu             ← veya uyarı
```

### 5.5 Hata Durumları

RPC `success: false` dönerse:
- `kapasite_dolu` → "Hedef padok doldu (20/20). Transfer iptal edildi."
- `validasyon` → hata mesajını göster
- Hiçbir hayvan taşınmaz (all-or-nothing).

---

## 6. Besi Etiket Akışı

### 6.1 Tetiklenme Koşulu

Kullanıcı hedef padok olarak Besi Padok seçtiğinde **ve** seçili hayvanlardan en az biri besi ile uyumsuz gruptaysa etiket modal'ı gösterilir.

### 6.2 Etiket Modal Yapısı

```
⚠️ Besi Padoğuna Transfer

Seçili N hayvan besi padoğu ile uyumsuz.
Devam etmek için etiket seçin.

── Toplu Ata ─────────────────────────────
[✓] Kısır    [ ] Satışta
Tüm hayvanlara uygulanacak

── veya Tek Tek Seç ──────────────────────
🐄 102 · Sağmal   [ ] Kısır  [ ] Satışta
🐄 103 · Sağmal   [ ] Kısır  [✓] Satışta

[Devam Et]  [İptal]
```

### 6.3 Kurallar

- Toplu ata seçilince tek tek seçimler sıfırlanır (ve tersi)
- Her hayvan için en az bir etiket seçilmeden `[Devam Et]` disabled
- Onaylanınca normal özet + `[🔀 Taşı]` akışına döner
- Transfer + etiket aynı RPC çağrısında gönderilir (`p_etiketler` parametresi)
- Etiketler mevcut etiketlerle birleştirilir (üzerine yazılmaz)

---

## 7. Değişecek Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `supabase/migrations/YENI.sql` | `etiketler` kolonu + index |
| `supabase/migrations/99999999999999_ground_truth.sql` | `padok_degistir` kapasite kontrolü + `padok_degistir_toplu` all-or-nothing rewrite |
| `index.html` | Padok doluluk bar HTML + `m-bulk-transfer` modal + action bar HTML |
| `js/ui.js` | `_btSecimModu`, `_btSecilenIds` state + tüm bt* fonksiyonlar + doluluk bar render |
| `js/utils/handlers.js` | `bt-toggle-mode`, `bt-transfer`, `bt-cancel`, `bt-onay`, tab handler'ları |

---

## 8. Kapsam Dışı

- Padok ekleme/düzenleme/silme UI (D spec)
- Kapasite değeri ayarlama (D spec ile birlikte gelir)
- 16 hayvan bug fix (D spec ile birlikte sıfırdan yazılır)
- Çıkış akışı (`durum = 'Çıktı'`) — mevcut çalışıyor, dokunma
- Kesimlik etiketi — kapsam dışı

---

## 9. Öncelik Sırası (Implementation)

```
P0: DB migration (etiketler kolonu)
P1: padok_degistir + padok_degistir_toplu RPC güncellemeleri
P2: Padok doluluk widget
P3: Seçim modu (toolbar + action bar + state)
P4: m-bulk-transfer modal
P5: Besi etiket akışı
P6: Handler kayıtları
```
