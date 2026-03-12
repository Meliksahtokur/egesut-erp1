# EgeSüt ERP — ARCHITECTURE
> Değişmez referans. Mimari kararlar, veri modeli, MVP tanımı, iş akışları burada.
> Sprint durumu → SPEC.md | Bu dosya nadiren güncellenir, her değişiklik bilinçli karar gerektirir.

---

## 1. ÜRÜN TANIMI

EgeSüt ERP, 130+ hayvanlık bir süt çiftliğinin **tüm operasyonel ihtiyaçlarını** karşılayan
web tabanlı yönetim sistemidir. Hedef kullanıcı: çiftlik sahibi, saha çalışanı, veteriner.

### MVP Kriteri (Ne Zaman "Çalışır Ürün" Diyebiliriz)

Aşağıdaki 5 domain'in tamamı production kalitesinde çalışıyorsa MVP tamamdır:

| # | Domain | Temel Akış |
|---|--------|------------|
| 1 | **Sürü** | Hayvan kaydı, kart, fiziksel alanlar, grup/padok, sürü filtresi |
| 2 | **Klinik** | Vaka aç → gün ekle → ilaç ekle → kapat (cases sistemi) |
| 3 | **Stok** | İlaç/malzeme girişi, kullanım düşümü, kritik eşik uyarısı |
| 4 | **Üreme** | Kızgınlık → tohumlama → gebelik takibi → doğum → buzağı |
| 5 | **Görev** | Otomatik görev üretimi, tamamlama, renk mantığı, aşılama |

### MVP Dışı (Sonraki Aşama)
- Muhasebe / gelir-gider
- Süt verim kaydı
- Raporlama ekranı
- Mobil native app
- Çoklu kullanıcı / rol yönetimi

---

## 2. TEKNİK STACK

| Katman | Teknoloji | Not |
|--------|-----------|-----|
| Frontend | Vanilla JS, tek `index.html` | Framework yok, bundle yok |
| Backend | Supabase (PostgreSQL) | RPC + REST API |
| Cache | IndexedDB (`egesut_v9`, DB_VER=6) | Offline okuma için |
| Deploy | GitHub Pages | Her push'ta otomatik |
| Migration | GitHub Actions → Supabase CLI | `supabase/migrations/` klasörü |
| Geliştirme | VS Code (Windows) + Acode/Termux (Android) | |

### URL'ler
```
Supabase : https://zqnexqbdfvbhlxzelzju.supabase.co
Live     : https://meliksahtokur.github.io/egesut-erp1/
Repo     : github.com/Meliksahtokur/egesut-erp1
```

---

## 3. MİMARİ PRENSİPLER (KURAL, İSTİSNASIZ)

### 3.1 Katman Sorumlulukları
```
UI Layer        → sadece veri toplar ve gösterir, hesap yapmaz
Application     → RPC çağrıları, hata yönetimi, state güncelleme
DB Layer        → tüm iş mantığı, validasyon, hesaplama, ledger
```

**"Frontend hesap yapmaz"** — DB'den hazır değer okumak filtredir, hesap değildir.

### 3.2 Controlled Entities (KESİNLİKLE FREE TEXT YASAK)
Aşağıdaki entity'ler **asla** text olarak saklanamaz. FK zorunludur.

| Entity | Tablo | Referans |
|--------|-------|---------|
| Hastalık/Tanı | `diseases` | `cases.disease_id → diseases.id` |
| İlaç | `drugs` | `drug_administrations.drug_id → drugs.id` |
| Hayvan | `hayvanlar` | tüm ilişkili tablolarda `animal_id text FK` |

UI'da bu entity'ler için **dropdown** (DB'den populate) zorunludur. Free text input yasaktır.

### 3.3 Stok Ledger Kuralları
```
stok_hareket.miktar POZİTİF  = kullanım/çıkış
stok_hareket.miktar NEGATİF  = iade/düzeltme (istisnai)
guncel_stok = baslangic_miktar - SUM(stok_hareket.miktar WHERE NOT iptal)
```
- `stok_hareket` kayıtları **asla silinmez, asla iptal=true yapılmaz**
- Her düzeltme yeni bir hareket INSERT'idir (ledger prensibi)
- `stok` tablosunda `miktar` kolonu yoktur — hesaplama her zaman `stok_hareket`'ten yapılır

### 3.4 Migration Kuralları
- Her migration **idempotent**: `DROP IF EXISTS + CREATE OR REPLACE`
- View güncellemede: `DROP VIEW IF EXISTS ... CASCADE` zorunlu
- Yeni tablo: RLS policy + SECURITY DEFINER zorunlu
- Migration dosyası repo'ya commit edilmeden SQL Editor'dan çalıştırılmaz

### 3.5 Render Kuralları
- Kritik işlem sonrası: `await renderFromLocal()` — direkt, senkron
- Background sync: `renderSafe()` — 60ms debounce, fire-and-forget
- Bu iki fonksiyon karıştırılmaz

---

## 4. VERİTABANI MODELİ

### 4.1 Schema Özeti

```
hayvanlar (çekirdek)
  ├── tohumlama
  ├── dogum
  ├── kizginlik_log
  ├── gorev_log
  ├── hastalik_log          ← eski sistem (korunuyor, yeni vaka yazmıyor)
  │     └── tedavi          ← eski sistem (korunuyor)
  └── cases                 ← YENİ vaka sistemi (mig-022)
        └── treatment_days
              └── drug_administrations
                    └── drugs → stok

stok
  └── stok_hareket          ← ledger (tüm sistemlerin paylaşımlı ledger'ı)

diseases                    ← controlled entity (mig-022)
drugs                       ← controlled entity (mig-022)
```

### 4.2 Yeni Vaka Sistemi (Migration 022)

**`diseases`** — Controlled hastalık listesi
```sql
id uuid PK, name text UNIQUE NOT NULL, category text
```

**`drugs`** — Controlled ilaç listesi, stok bağlantılı
```sql
id uuid PK, name text UNIQUE NOT NULL,
stock_item_id text FK→stok.id,  -- NULL ise stok düşümü yapılmaz
default_unit text, default_route text
```

**`cases`** — Vaka katmanı
```sql
id uuid PK, animal_id text FK→hayvanlar.id,
disease_id uuid FK→diseases.id,
start_date date, status text CHECK('active','closed'),
notes text, closed_at timestamptz
```

**`treatment_days`** — Günlük tedavi (day_no trigger ile artar)
```sql
id uuid PK, case_id uuid FK→cases.id CASCADE,
day_no integer (trigger), treatment_date date
```

**`drug_administrations`** — İlaç uygulama
```sql
id uuid PK, treatment_day_id uuid FK→treatment_days.id CASCADE,
drug_id uuid FK→drugs.id,
dose numeric NOT NULL CHECK(>0), unit text NOT NULL,
route text CHECK('IM','IV','SC','PO','Topikal','Intrauterin')
```

### 4.3 Migration Tablosu

| # | Dosya | İçerik | Durum |
|---|-------|---------|-------|
| 001-005 | initial_schema → triggers | Temel şema | ✅ |
| 006 | faz1_core | Views, RPC'ler, stok_tuketim_view | ✅ |
| 008 | blok1_backend | Ana RPC paketi | ✅ |
| 009 | sperma_stok_fix | Tohumlama validasyon | ✅ |
| 010 | hayvan_guncelle | COALESCE pattern | ✅ |
| 012 | trigger_fix | _islem_log_yaz CASE fix | ✅ |
| 013 | ground_truth | Tüm proc'lar yeniden tanım (SQL Editor) | ✅* |
| 014 | tohumlanabilir_hayvanlar | View (SQL Editor) | ✅* |
| 016-018 | ref_id, hastalik RPC'ler | Cast fix, sil fix | ✅ |
| 019 | tedavi_yeniden_tasarim | tedavi tablosu + RPC'ler | ✅ |
| 020 | hastalik_guncelle_tarih | p_tarih parametresi | ✅ |
| 021 | tedavi_guncelle | Ledger düzeltme, audit kolonları | ✅ |
| **022** | **case_management** | **diseases, drugs, cases sistemi** | **🔜** |

*013 ve 014 dosyaları repo'da yok — SQL Editor'dan uygulandı. Drift mevcut.

### 4.4 Bilinen Teknik Borç

| Sorun | Önem | Plan |
|-------|------|------|
| `hastalik_log.ilac_stok_id` ve `ilac_miktar` orphan kolonlar | 🟡 | mig-023'te DROP |
| `buzagi_takip` tablosu orphan, hiç kullanılmıyor | 🟡 | mig-023'te DROP veya entegre et |
| `hastalik_log.tani` free text (eski kayıtlar) | 🟡 | yeni vakalar `cases` ile çözüldü |
| Migration 013-014 repo'da yok | 🟠 | ground truth sync migration yaz |

---

## 5. İŞ AKIŞLARI

### 5.1 Klinik Vaka Akışı (YENİ — Migration 022 sonrası)
```
1. Hayvan seç
2. Tanı seç (diseases dropdown — free text yasak)
3. create_case(animal_id, disease_id) → case_id
4. + Gün ekle → add_treatment_day(case_id) → day_id
5. + İlaç ekle → add_drug_administration(day_id, drug_id, dose, unit, route)
      └── Trigger: stok_hareket INSERT (pozitif miktar)
6. Vaka kapat → close_case(case_id)
```

**Kural:** Kapalı vakaya gün/ilaç eklenemez (RPC'de kontrol edilir).

### 5.2 Stok Akışı
```
Giriş  : stok_hareket INSERT (negatif miktar)   → frontend SUM'u düşürür stok'u artırır
Kullanım: stok_hareket INSERT (pozitif miktar)  → frontend SUM'u artırır stok'u düşürür
Görüntü : guncel = baslangic_miktar - SUM(miktar WHERE NOT iptal)
```

### 5.3 Üreme Akışı
```
Kızgınlık kaydı
  ↓
Tohumlama kaydı (sperma: stok'tan seç veya manuel)
  → Trigger: 21. ve 35. gün kontrol görevleri
  ↓
Gebelik onayı (tohumlama.sonuc = 'Gebe')
  ↓
Doğum kaydı
  → Trigger: buzağı hayvanlar'a eklenir
  → Trigger: tohumlama.sonuc = 'Doğurdu'
```

---

## 6. FRONTEND YAPISI

```
index.html      — HTML + CSS + tüm modaller
js/api.js       — Supabase client, pullTables, renderSafe, rpcOptimistic, IndexedDB
js/app.js       — init, routing, global state, dropdown yardımcıları
js/ui.js        — tüm render fonksiyonları
js/forms.js     — tüm submit / RPC çağrıları
```

### Global State
```javascript
window._appState = {
  hayvanlar: [],    // hayvan_durum_view
  stok: [],         // stok tablosu
  gorevler: [],     // gorev_log
  gecmis: [],       // islem_log
  bildirimler: [],  // bildirim_log
}
window._TH = []     // tohumlanabilir_hayvanlar
```

---

## 7. SONRAKI BÜYÜK ADIMLAR (Öncelik Sırasıyla)

### Aşama 1 — Klinik Modül (Migration 022 sonrası)
Migration 022 DB'ye uygulandıktan sonra frontend akışı yazılır:
- `diseases` ve `drugs` dropdown'ları DB'den
- Vaka açma formu → `create_case()` RPC
- Gün + ilaç ekleme UI → `add_treatment_day()` + `add_drug_administration()`
- `treatment_timeline` view'dan vaka detay görünümü
- Vaka kapatma → `close_case()`
- `drugs` tablosuna stok bağlama UI (hangi ilaç hangi stok kalemi)

### Aşama 2 — Aşılama Modülü
- `vaccines` controlled entity tablosu
- Aşılama protokolleri (yaş/ağırlığa göre otomatik görev)
- `vaccination_records` tablosu
- Sürü bazlı toplu aşılama

### Aşama 3 — Toplu İşlem Paneli
- Sürü seç → toplu ilaç / aşı / görev
- `bulk_operations` RPC

### Aşama 4 — Teknik Borç Temizliği
- Migration 023: orphan kolonları temizle, 013-014 drift'ini çöz
- Supabase Realtime + eventBus.js (pullTables setInterval kaldır)

---

## 8. DEĞİŞMEZ KARARLAR

Bu kararlar tartışmaya açık değildir, değiştirmek için özel gerekçe gerekir:

1. **Service Worker yok** — uygulama live Supabase bağlantısı gerektirir
2. **Framework yok** — Vanilla JS, bundle yok, build step yok
3. **Stok ledger'ı immutable** — `stok_hareket` asla silinmez/iptal edilmez
4. **İş mantığı DB'de** — frontend sadece render ve input toplar
5. **Controlled entities FK zorunlu** — hastalık, ilaç, hayvan asla free text
6. **Her migration idempotent** — tekrar çalıştırılabilir, yan etkisiz
