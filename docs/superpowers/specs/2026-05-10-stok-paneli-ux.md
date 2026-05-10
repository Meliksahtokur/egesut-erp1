# Spec: Stok Paneli UX İyileştirmesi

**Tarih:** 2026-05-10
**Öncelik:** ORTA
**Bağımlılık:** Yok (bağımsız)

---

## Mevcut Durum

### Stok Paneli (id="stok-panel")
- Tam ekran slide-in panel (translateX)
- Dikey scroll: TÜM ürünler tek listede
- Sadece "Yeni Ürün Ekle" ve "Tüm Hareketler" butonları
- Ürün güncelleme İMKANSIZ
- Ürün silme YOK
- Kategoriler: Antibiyotik, Aşı, Sperma, Vitamin, Anthelmintic, NSAID, vb.

### Stok Tablosu (mevcut)
```
stok: id, urun_adi, tur, birim, baslangic_miktar, esik, maliyet, kategori, drug_product_id
stok_hareket: stok_id, miktar, islem_tipi, tarih, not, iptal, kaynak
```

### Sorunlar
1. Tüm ürünler tek listede → 20+ ürün arasında arama zor
2. Ürün bilgisi (isim, eşik, birim) güncellenemiyor
3. Kategori bazlı görünüm yok
4. Stok durumu (mevcut miktar) bir bakışta anlaşılmıyor

---

## Hedef Tasarım

### Sekmeli Yapı

```
📦 Stok
[💊 İlaç] [💉 Aşı] [🧬 Sperma] [📦 Diğer]

┌─────────────────────────────────────────────┐
│ Makrovil          250ml  │ ▪▪▪░░ 180/250  [✏️]│
│ Enrolen            15ml  │ ▪░░░░  12/15   [✏️]│
│ Florkem             5ml  │ ▪░░░░   3/5    [✏️]│
└─────────────────────────────────────────────┘
[+ Yeni Ürün Ekle]
```

### Sekme Kategorileri
| Sekme | `stok.kategori` eşleşmesi |
|-------|--------------------------|
| 💊 İlaç | Antibiyotik, NSAID, Anthelmintic, Diğer İlaç |
| 💉 Aşı | Aşı |
| 🧬 Sperma | Sperma |
| 📦 Diğer | Vitamin, Sarf, kategorisiz |

### Ürün Kartı
Her kart gösterecek:
- Ürün adı
- Mevcut stok / eşik (progress bar ile görsel)
- Birim (ml, adet, vb.)
- Tıklanınca: detay modal

---

## Ürün Güncelleme (YENİ)

### Ürün Detay Modal (tıklanınca açılır)
```
┌─── Makrovil ─────────────────────┐
│ Ürün Adı:    [Makrovil         ] │
│ Kategori:    [Antibiyotik    ▼ ] │
│ Birim:       [ml             ▼ ] │
│ Kritik Eşik: [250              ] │
│ Maliyet:     [0                ] │
│                                   │
│ Stok Durumu: 180ml               │
│ Son Hareket: -5ml (2 gün önce)   │
│                                   │
│ [💾 Kaydet] [🗑 Sil] [İptal]    │
└───────────────────────────────────┘
```

### Implementasyon
- `openStokDet(id)` → stok + stok_hareket çek → modal render
- Düzenleme: `write('stok', {...updates}, 'PATCH', 'id=eq.XXX')`
- Silme: stok_hareket varsa → "Hareketli ürün silinemez, arşivle" seçeneği
- Arşivleme: `stok.aktif = false` → listeden kaldır ama data korunsun

### Stok Ekleme Geliştirmesi
- Mevcut `m-stok-add` modal'ı yeterli
- Ek: "kategori" alanını dropdown yap (hardcoded değil, mevcut kategorilerden)
- Aşı eklenirken: `vaccines` tablosuyla ilişkilendir (rapel süresi burada ayarlanır)

---

## Stok Miktar Düzeltme (Manuel)

### Kullanım Senaryosu
- Sayım sonrası gerçek miktar farklıysa düzeltme yapılabilmeli
- "Stok Düzelt" butonu → miktar gir → stok_hareket(islem_tipi='DUZELTME')

### UI
- Ürün detay modal'ında: "📊 Stok Düzelt" butonu
- Yeni miktar gir → fark hesaplanır → stok_hareket INSERT

---

## Stok Hareketleri İyileştirmesi

### Mevcut
- "Tüm Hareketler" → tek uzun liste, filtresiz

### Hedef
- Ürün bazlı filtreleme (dropdown)
- Tarih aralığı seçimi
- İşlem tipi filtresi (giriş/çıkış/düzeltme)

---

## Test Senaryosu

1. Stok paneli aç → sekmeler görünür (İlaç aktif)
2. "Aşı" sekmesi → sadece aşılar listelenir
3. Ürün kartına tıkla → detay modal → bilgileri güncelle → Kaydet ✅
4. Yeni ürün ekle → kategori seç → listede doğru sekmede görünür
5. Stok düzelt → miktar güncellenir → hareket kaydı oluşur
6. Sperma sekmesi → "Starred" mock varsa görünür (silme test)
