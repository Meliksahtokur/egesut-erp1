# Tanımlar Paneli — Hastalık, İlaç, Kategori CRUD

**Tarih:** 2026-05-29
**Durum:** Onaylandi
**Oncelik:** Yuksek (Task-042 bagimli)

## Amac

Sisteme el ile hastalık, ilaç ve stok kategorisi ekleme/düzenleme/silme imkanı vermek. Şu an kullanıcı DB ile çalışmaya mecbur — production'da kabul edilemez.

## Panel Yapısı

Stok paneli ile birebir aynı pattern: full-screen slide-in (`translateX` animasyon), sekmeli yapı.

**Tetikleme:** Dashboard'da (Kayıt sekmesi) Stok Modülü butonunun altına:
```
📦 Stok Modülü        →
📋 Tanımlar           →    ← YENİ
```

Aynı `log-btn` stili, `data-action="open-tanimlar-panel"`.

### Sekmeler

| Sekme | Tablo | İçerik |
|-------|-------|--------|
| 🏥 Hastalıklar | `diseases` | Ad, kategori, aktif vaka sayısı |
| 💊 İlaçlar | `drugs` | Ad, varsayılan birim/yol, stok bağlantısı |
| 📂 Kategoriler | `stok_kategorileri` (yeni) | Ad, bağlı ürün sayısı |

Varsayılan sekme: Hastalıklar.

## Hastalıklar Sekmesi

### Kart Görünümü
- Hastalık adı (bold)
- Kategori pill (Meme/Üreme/Metabolik/Ayak/Solunum/Sindirim/Buzağı/Diğer)
- Aktif vaka sayısı (`cases WHERE disease_id=X AND status='active'` count)
- Düzenle ikonu

### Ekleme
- "+ Yeni Hastalık" butonu → inline form:
  - Ad (text input, zorunlu)
  - Kategori (dropdown — 8 sabit seçenek, zorunlu)
- RPC: `disease_ekle(p_name text, p_category text) RETURNS jsonb`
  - UNIQUE constraint: aynı isim varsa `{"ok":false,"mesaj":"Bu hastalık zaten var"}`
  - Başarı: `{"ok":true,"id":"uuid"}`

### Düzenleme
- Karta tıkla → aynı inline form (ad + kategori dolu gelir)
- RPC: `disease_guncelle(p_id uuid, p_name text, p_category text) RETURNS jsonb`
  - UNIQUE constraint kontrolü

### Silme
- Düzenleme formunda kırmızı "Sil" butonu
- Frontend confirm dialog: "Bu hastalığı silmek istediğinize emin misiniz?"
- RPC: `disease_sil(p_id uuid) RETURNS jsonb`
  - `cases` tablosunda kayıt varsa → `{"ok":false,"mesaj":"Bu hastalığa ait vaka var, silinemez"}`
  - Yoksa DELETE → `{"ok":true}`

### Varsayılana Dön
- Listenin altında gri `🔄 Varsayılana Dön` linki
- Confirm: "Standart hastalık tanımları geri yüklenecek. Mevcut özel tanımlarınız silinmez. Devam?"
- RPC: `seed_defaults('diseases')` → standart hastalıklar ON CONFLICT DO NOTHING

### Hastalık Kategori Listesi (Sabit — Faz 2'de Dinamik)
Meme, Üreme, Metabolik, Ayak, Solunum, Sindirim, Buzağı, Diğer

## İlaçlar Sekmesi

### Kart Görünümü
- İlaç adı (bold)
- Varsayılan yol pill (IM/IV/SC/PO/Topikal/Intrauterin)
- Stok bağlantısı: varsa `📦 Makrovil (180ml)`, yoksa `⚠️ Stok bağlantısı yok` (gri)

### Ekleme
- "+ Yeni İlaç" butonu → inline form:
  - Ad (text, zorunlu)
  - Varsayılan birim (ml/mg/cc/adet — dropdown)
  - Varsayılan yol (IM/IV/SC/PO/Topikal/Intrauterin — dropdown)
  - Stok bağlantısı (opsiyonel — `stok` tablosundan dropdown, sadece bağlanmamış ürünler)
- RPC: `drug_ekle(p_name text, p_default_unit text, p_default_route text, p_stock_item_id text) RETURNS jsonb`

### Düzenleme
- Karta tıkla → inline form (dolu gelir)
- Stok bağlantısı değiştirilebilir/kaldırılabilir
- RPC: `drug_guncelle(p_id uuid, p_name text, p_default_unit text, p_default_route text, p_stock_item_id text) RETURNS jsonb`

### Silme
- RPC: `drug_sil(p_id uuid) RETURNS jsonb`
  - `drug_administrations` tablosunda bu ilacın `stock_item_id`'si ile eşleşen `stok_id` kaydı varsa reddet
  - `{"ok":false,"mesaj":"Bu ilaç tedavide kullanılmış, silinemez"}`
  - Hiç kullanılmamışsa DELETE → `{"ok":true}`

### Varsayılana Dön
- `seed_defaults('drugs')` → standart ilaçlar ON CONFLICT DO NOTHING

## Kategoriler Sekmesi (Stok Kategorileri)

### Yeni Tablo
```sql
CREATE TABLE IF NOT EXISTS public.stok_kategorileri (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad    text UNIQUE NOT NULL,
  sira  integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);
```

Seed data: Antibiyotik, NSAID, Hormon, Vitamin, Antiparaziter, Diğer İlaç, Aşı, Sperma, Yem, Sarf, Ekipman, Diğer (12 adet)

### Kart Görünümü
- Kategori adı (bold)
- Bağlı ürün sayısı (`stok WHERE kategori=X` count)

### Ekleme
- "+ Yeni Kategori" → inline form: ad (text, zorunlu)
- RPC: `kategori_ekle(p_ad text) RETURNS jsonb`

### Düzenleme
- Ad değişince bağlı stok kayıtları da güncellenir (cascade)
- RPC: `kategori_guncelle(p_id uuid, p_new_ad text) RETURNS jsonb`
  - UPDATE stok SET kategori = p_new_ad WHERE kategori = (SELECT ad FROM stok_kategorileri WHERE id = p_id)
  - UPDATE stok_kategorileri SET ad = p_new_ad WHERE id = p_id

### Silme
- Bağlı stok ürünü varsa reddet
- RPC: `kategori_sil(p_id uuid) RETURNS jsonb`

### Varsayılana Dön
- `seed_defaults('kategoriler')` → 12 standart kategori ON CONFLICT DO NOTHING

### Stok Paneli Etkisi
- `_TAB_FILTER` hardcoded listesi → `stok_kategorileri` tablosundan dinamik yüklenir
- Stok ekleme formundaki kategori dropdown'u bu tablodan beslenir
- IDB sync'e `stok_kategorileri` eklenir

## seed_defaults RPC

```sql
CREATE OR REPLACE FUNCTION seed_defaults(p_tip text) RETURNS jsonb
```

- `p_tip = 'diseases'` → standart hastalıklar INSERT ON CONFLICT DO NOTHING
- `p_tip = 'drugs'` → standart ilaçlar INSERT ON CONFLICT DO NOTHING
- `p_tip = 'kategoriler'` → 12 standart kategori INSERT ON CONFLICT DO NOTHING
- Sadece eksik olanları ekler, mevcut veriyi silmez/değiştirmez

## Etkilenen Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `index.html` | Tanımlar butonu (dashboard) + slide-in panel HTML |
| `js/ui.js` | `loadTanimlarPanel`, `setTanimlarTab`, kart render, inline form |
| `js/utils/handlers.js` | Action handler'lar (open/close, sekme, CRUD, varsayılana dön) |
| `js/forms.js` | RPC submit fonksiyonları |
| `js/app.js` | `_tanimlarTab` global state |
| `js/api.js` | `stok_kategorileri` FETCHERS'a ekleme |
| `supabase/migrations/` | Yeni migration (tablo + RPC'ler + seed + RLS) |

## Değişmeyen

- Stok paneli (sadece `_TAB_FILTER` dinamik olur)
- Tedavi akışı, vaka yönetimi, görevler
- Ayarlar modal'ı
- Mevcut hastalık dropdown'ları (forms.js `loadDiseasesDropdown`) — IDB cache'ten okuyor, yeni tanım eklenince pullTables ile sync

## IDB Sync

- `stok_kategorileri` → FETCHERS'a ekleme, DB_VER bump
- `diseases` ve `drugs` zaten sync ediliyor — değişiklik yok

## Faz 2 (İleride)

- Hastalık kategorilerini dinamik yapma (ayrı tablo)
- `drug_classes` / `drug_products` tablo yapısı (hayalet tablolar)

## Risk

Düşük. Mevcut akışlara dokunmuyor, yeni panel + RPC ekleniyor. Tek dikkat noktası `_TAB_FILTER` dinamik yapılması — stok panelini etkiler ama kontrollü geçiş.
