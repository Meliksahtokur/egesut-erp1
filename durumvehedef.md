# EgeSüt ERP — Mevcut Durum, Mimari Hedefler ve Bug Raporu
> Tarih: 2026-03-22 | Oturum sonu snapshot

---

## 1. GENEL MİMARİ

### Stack
- **Frontend:** Vanilla JS, tek `index.html`
- **Backend:** Supabase (PostgreSQL + RPC)
- **Cache:** IndexedDB (`egesut_v12`, DB_VER=12)
- **Deploy:** GitHub Pages (otomatik, her push)

### Katman Sorumlulukları
```
UI         → veri toplar, render eder, hesap yapmaz
Frontend   → RPC çağrıları, state yönetimi, IDB cache
Backend    → iş mantığı, validasyon, stok ledger, trigger'lar
```

### State Yönetimi
- `js/state.js` → merkezi AppState (EventEmitter tabanlı)
- `getState('animals')`, `setState('animals', data)` pattern'i
- Eski `_A`, `_S` global değişkenleri kaldırıldı, state'e taşındı

---

## 2. VERİTABANI MİMARİSİ

### 2.1 Ana Tablolar
```
hayvanlar           → sürü, hayvan kartları
tohumlama           → üreme takibi
dogum               → doğum kayıtları
kizginlik_log       → kızgınlık gözlemleri
gorev_log           → görevler (otomatik + manuel)
stok                → fiziksel envanter (ilaç, sperma, ekipman)
stok_hareket        → stok ledger (immutable, asla silinmez)
islem_log           → işlem geçmişi
bildirim_log        → bildirimler
cases               → veteriner vakaları
diseases            → hastalık listesi (controlled entity)
```

### 2.2 İLAÇ HİYERARŞİSİ (YENİ — Migration 028)

Hedef yapı:
```
drugs (üst kategori)
  id, name
  Değerler: 'İlaç', 'Ekipman', 'Yem'
       ↓
drug_classes (ilaç sınıflandırması)
  id, drug_id FK→drugs
  group_name      → 'Antibiyotik', 'NSAID', 'Hormon'...
  class_name      → 'Makrolid', 'Florokinolon', 'Beta-Laktam'...
  active_ingredient → 'Tilmikosin', 'Enrofloksasin', 'Marbofloksasin'...
       ↓
drug_products (preparatlar)
  id, drug_class_id FK→drug_classes
  brand_name      → 'Makrovil', 'Marbox', 'Florkem'...
  concentration   → 100 (mg/ml)
  default_route   → 'IM', 'IV', 'SC', 'PO'...
  default_unit    → 'ml', 'gr'...
       ↓
stok (envanter)
  id, drug_product_id FK→drug_products (ilaç ise)
  urun_adi, miktar, birim, esik, kategori
```

**Örnek:**
```
İlaç → Antibiyotik → Makrolid → Tilmikosin → Makrovil (300mg/ml, 500ml stokta)
İlaç → Antibiyotik → Florokinolon → Marbofloksasin → Marbox (100mg/ml, 200ml stokta)
```

### 2.3 TEDAVİ AKIŞI
```
cases (vaka)
  animal_id FK→hayvanlar
  disease_id FK→diseases
  status: 'active' | 'closed'
       ↓
treatment_days (tedavi günleri)
  case_id FK→cases
  day_no (trigger ile otomatik artar)
  treatment_date
       ↓
drug_administrations (ilaç uygulamaları)
  treatment_day_id FK→treatment_days
  drug_product_id FK→drug_products  ← YENİ
  stok_id FK→stok                   ← YENİ (stok düşümü için)
  dose, unit, route
```

### 2.4 STOK LEDGER KURALI
```
stok_hareket.miktar POZİTİF = kullanım/çıkış
guncel_stok = baslangic_miktar - SUM(stok_hareket.miktar WHERE NOT iptal)
```
- `stok_hareket` asla silinmez, asla `iptal=true` yapılmaz
- Her düzeltme yeni INSERT'tir

### 2.5 Seed Data (drug_classes)
29 kayıt mevcut:
- Antibiyotik: Beta-Laktam, Makrolid, Florokinolon, Tetrasiklin, Aminoglikozid, Sülfonamid
- NSAID: Meloksikam, Ketoprofen, Flunixin
- Hormon: Oksitosin, Progesteron, GnRH, Prostaglandin
- Metabolik: Kalsiyum, Glukoz, Magnezyum
- Vitamin: B Grubu, AD3E, C
- Antiparaziter, Kortikosteroid, Rumen, Elektrolit

---

## 3. FRONTEND DURUMU

### 3.1 Çalışan Özellikler ✅
- Hayvan listesi, kart, filtreleme
- Vaka açma (`create_case` RPC)
- Tedavi günü ekleme (`add_treatment_day` RPC)
- Vaka kapatma (anlık UI güncelleme)
- Geçmiş sekmesi (hayvan no görünüyor, tıklanınca modal)
- Dashboard (aktif vaka, gebe, görev sayıları)
- Stok paneli açılıyor, kalemler görünüyor
- +Miktar butonu çalışıyor, stok güncelleniyor
- Aynı isimli stok birleşiyor (duplicate yok)
- Tedavide stok düşümü çalışıyor

### 3.2 Kırık / Eksik Özellikler ❌

#### KRİTİK
1. **Tedaviye ilaç ekleme UI yeni mimariye bağlı değil**
   - `caseDrugFormAc` → `drug_products` tablosundan listelemeli
   - Şu an `_drugsCache` boş geliyor çünkü `drug_products` IDB'ye gelmiyor
   - Kullanıcı text yazıyor, eşleşme olmuyor

2. **`drug_classes` / `drug_products` IDB'ye gelmiyor**
   - `TABLES` dizisinde var, `FETCHERS`'da var
   - `DB_VER=12`, `egesut_v12` DB adı
   - Tablet tarayıcısında hala eski cache çalışıyor olabilir
   - Kök neden: `onupgradeneeded` yeni store'ları eklemiyor olabilir

3. **Yeni ilaç eklenince `drug_products`'a gitmiyor**
   - Etken madde dropdown boş geldiği için `etkenId = null`
   - `if (etkenId)` koşulu false → `drug_products` INSERT atlanıyor

#### ÖNEMLİ
4. **Stok panelinde ilaç-tedavi bağlantısı gösterimi eksik**
   - `drug_product_id` stok kaleminde var ama UI'da gösterilmiyor
   - Stoka eklenen ama `drug_products`'a bağlanmamış eski kayıtlar var

5. **Uygulama yolu çoklu seçim olmalı**
   - Şu an tek `<select>` — checkbox veya multi-select olmalı

6. **Stok ekleme not alanı kaldırıldı**
   - `stok_hareket`'e not yazılmıyor artık

#### KÜÇÜK
7. **Geçmiş sekmesinde bazı hastalık kayıtları `?` gösteriyor**
   - Eski `hastalik_log` kayıtları (cases öncesi sistem)

8. **Stok panelinde eski `drugs` bağlantısı dropdown'ı kalıntısı**
   - Kaldırıldı ama bazı kartlarda hala görünüyor olabilir

---

## 4. RPC FONKSİYONLARI (Backend)

| RPC | Durum | Notlar |
|-----|-------|--------|
| `create_case` | ✅ | |
| `add_treatment_day` | ✅ | day_no trigger ile artar |
| `add_drug_administration` | ✅ | `p_drug_product_id` + `p_stok_id` parametreleri |
| `close_case` | ✅ | |
| `remove_drug_administration` | ✅ | |
| `hayvan_ekle` | ✅ | |
| `dogum_kaydet` | ✅ | |
| `tohumlama_kaydet` | ✅ | |
| `hastalik_kaydet` | ⚠️ | Eski sistem, yeni cases ile çakışıyor |
| `link_drug_to_stock` | ❌ Kaldırılacak | Eski mimari |

---

## 5. SONRAKI ADIMLAR (Öncelik Sırası)

### Acil
1. **IDB `drug_classes`/`drug_products` sorunu çöz**
   - Muhtemelen `onupgradeneeded` içinde store oluşturulmuyor
   - DB adını değiştirmek yerine `openDB` fonksiyonunu debug et

2. **Tedavi ilaç ekleme UI**
   - `caseDrugFormAc` → autocomplete, `drug_products`'tan
   - Arama: "mar" → Marbox (Marbofloksasin) göstermeli
   - Stok miktarı yanında görünmeli
   - Seçilince `p_drug_product_id` + `p_stok_id` RPC'ye gitmeli

3. **Yeni ilaç ekleme akışı düzelt**
   - Etken madde dropdown'ı dolu gelsin
   - Zorunlu alan — seçilmeden kayıt olmasın
   - `drug_products` → `stok` bağlantısı kurulsun

### Kısa Vadeli
4. Uygulama yolu çoklu seçim (checkbox)
5. Stok hareketi not alanı geri ekle
6. `link_drug_to_stock` RPC'yi ve ayarlardaki kalıntıları temizle
7. Vaka iptal butonu (geri alınabilir)

### Orta Vadeli
8. VAC-01: Aşılama modülü
9. Yem modülü (placeholder hazır)
10. Ekipman modülü
11. `geri_al` RPC yeniden tasarım (snapshot formatı)
12. Supabase Realtime (setInterval kaldır)

---

## 6. BİLİNEN TEKNİK BORÇ

| Sorun | Önem |
|-------|------|
| `hastalik_log` orphan (eski sistem) | 🟡 |
| `tedavi` tablosu orphan (eski sistem) | 🟡 |
| `drugs.stock_item_id` kolonu kalıntı | 🟡 |
| `link_drug_to_stock` RPC gereksiz | 🟡 |
| Migration 013-014 repo'da yok | 🟠 |
| `_curPg`, `_curTaskFilter` vb. routing state henüz state.js'e taşınmadı | 🟡 |
| Debug div (`dbg-hint`) kod içinde kaldı | 🟢 |
