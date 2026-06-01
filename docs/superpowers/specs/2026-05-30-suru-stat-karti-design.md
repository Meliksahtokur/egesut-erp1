# Sürü İstatistik Kartı — Tasarım Dokümanı

**Tarih:** 2026-05-30
**Durum:** Tasarım onaylandı
**Bağımlılık:** Mevcut `stat_gebelik_ozet` RPC (taşınacak/genişletilecek)

---

## Amaç

Sürü sekmesindeki `#padok-ozet` chip'lerinin yerine, accordion tarzı açılır-kapanır istatistik kartı koyarak hayvan demografisi + gebelik istatistiklerini tek noktada sunmak. Padok dropdown ile dinamik filtreleme. Tüm hesaplamalar PostgreSQL'de yapılır.

---

## Kararlar

| Karar | Seçim |
|-------|-------|
| Konum | `#padok-ozet` div'inin yerine |
| RPC | Tek RPC: `stat_suru_ozet(p_padok)` |
| Cache | Padok bazlı map, TTL yok, `pullTables` ile invalidate |
| Yükleme | Fire-and-forget, `loadAnimals` ile paralel, blocking yok |
| Güncelleme | Padok değişince eski veri gösterilir + mini spinner, RPC gelince smooth geçiş |

---

## 1. RPC: `stat_suru_ozet`

```sql
stat_suru_ozet(
  p_padok text DEFAULT NULL
) RETURNS jsonb
```

### Döndürdükleri

```jsonc
{
  "hayvan": {
    "toplam": 45,
    "inek": 28,
    "duve": 10,
    "buzagi": 5,
    "erkek": 2,
    "kisir": 3,
    "hasta": 3        // cases tablosu, status='active'
  },
  "gebelik": {
    "ozet": {
      "toplam": 42,   // tohumlama sayısı
      "gebe": 12,
      "bos": 25,
      "abort": 0,
      "bekleyen": 5,
      "oran": 36.2
    },
    "kategori": [
      {"ad": "İnek", "toplam": 98, "gebe": 39, "oran": 39.8},
      {"ad": "Düve", "toplam": 15, "gebe": 2, "oran": 13.3}
    ],
    "sperma_top5": [
      {"ad": "starred", "toplam": 64, "gebe": 35, "oran": 54.7}
    ],
    "deneme": [
      {"no": 1, "gebe": 7, "toplam": 23, "oran": 30.4},
      {"no": 2, "gebe": 14, "toplam": 31, "oran": 45.2},
      {"no": 3, "gebe": 11, "toplam": 29, "oran": 37.9},
      {"no": 4, "gebe": 5, "toplam": 18, "oran": 27.8},
      {"no": 5, "gebe": 3, "toplam": 12, "oran": 25.0}
    ]
  }
}
```

### SQL Mimarisi

Tek fonksiyon, üç CTE:

1. **`hayvan_stats`** — `hayvanlar` tablosu, `durum='Aktif'`, padok filtresi. `grup` adından inek/düve/buzağı/erkek ayrımı (ILIKE pattern). Kısır: `kisir=true`. Hasta: `cases` tablosu join.
2. **`tohum_base`** — Mevcut `stat_gebelik_ozet` mantığı. Aynı padoktaki hayvanların tohumlamaları.
3. **Sonuç** — `jsonb_build_object` ile iki CTE'nin çıktılarını birleştirir.

### Mevcut `stat_gebelik_ozet` ile ilişki

- Yeni `stat_suru_ozet` oluşturulur, `stat_gebelik_ozet`'in tohumlama mantığını içerir
- `stat_gebelik_ozet` silinmez (backward compat), ama üreme sekmesindeki `_renderUremeStat` ileride `stat_suru_ozet`'e geçebilir
- `deneme` kırılımı artık 3+'da gruplamaz — her deneme_no ayrı satır döner (sub-accordion UI'da gösterilecek)

---

## 2. UI: Kart Yapısı

### Konum

`index.html`'de `#padok-ozet` div'i `#suru-stat-card` olarak yeniden adlandırılır (veya yerine konur). Filtre chip'lerinin (`#filtre-strip`) hemen altında, `#suru-body`'nin hemen üstünde.

### Kapalı Hal

```
🐄 45 hayvan · 🤰 12 gebe (%36) · 🏥 3 hasta     ▼
```

Padok seçiliyse:
```
🏠 Sağmal Padok — 🐄 28 hayvan · 🤰 10 gebe (%40) · 🏥 1 hasta     ▼
```

### Açık Hal (Accordion)

```
🐄 45 hayvan · 🤰 12 gebe (%36) · 🏥 3 hasta     ▲

─── Demografik ───
🐄 İnek: 28  ·  🐮 Düve: 10  ·  🐂 Erkek: 2  ·  🍼 Buzağı: 5  ·  💲 Kısır: 3

─── Gebelik ───
💉 42 tohumlama · ✅ 12 gebe · ⭕ 25 boş · ⏳ 5 bekleyen
🐄 İnek: %40 (98 tohum)  ·  🐮 Düve: %13 (15 tohum)

─── Top Spermalar (≥3 tohum) ───
starred — 64 tohum → %55
armada red — 20 tohum → %20

─── Deneme Dağılımı ───
1. deneme: %30  ·  2. deneme: %45  ·  3. deneme: %38
[+2 daha]  ← tıkla → 4. deneme: %28  ·  5. deneme: %25  [Daralt]
```

### Deneme Sub-Accordion

- İlk 3 deneme her zaman görünür
- 3'ten fazla varsa `[+N daha]` butonu gösterilir
- Tıklanınca geri kalanı açılır, buton `[Daralt]`'a döner
- Tekrar tıklanınca ilk 3'e döner

### Toggle Mekanizması

- Mevcut CSS pattern: `.stat-card.open .stat-detail { display: block }`
- `onclick` → class toggle, JS'te `_suruStatOpen` boolean

---

## 3. Veri Akışı

```
Tab açılır (go-suru)
  ├─ loadAnimals()        → hayvan listesi render (mevcut)
  └─ _renderSuruStat()    → fire-and-forget, no await
        ├─ cache var? → anında render
        └─ cache yok? → RPC çağır, gelince render

Padok dropdown değişir (#pflt change)
  ├─ filterA()             → hayvan listesi client-side filtrele (mevcut, anında)
  └─ _renderSuruStat()     → cache varsa anında + arka planda RPC
        └─ RPC sırasında → eski veri + mini loading ikonu (sağ üstte küçük spinner)
        └─ RPC gelince → smooth güncelle, spinner kaybol

pullTables() çağrılır (veri değişikliği)
  └─ _suruStatCache = {}   → tüm cache sıfırlanır
```

### Cache Yapısı

```js
// Padok bazlı cache map
let _suruStatCache = {};
// '' key = tüm padoklar, 'Sağmal Padok' key = o padok

// Örnek
_suruStatCache['Sağmal Padok'] = { hayvan: {...}, gebelik: {...} };
```

- TTL yok — sadece `pullTables` ile sıfırlanır
- Padok değiştir → geri gel → cache'ten anında

---

## 4. Mevcut Koddan Kaldırılacaklar

| Dosya | Ne | Neden |
|-------|----|-------|
| `index.html` | `#ureme-stat-card` div | Üreme sekmesinden taşınıyor |
| `index.html` | `#padok-ozet` div | Stat kartıyla değişiyor |
| `js/ui.js` | `_renderUremeStat`, `_applyStatHtml`, `_toggleUremeStat` | Yeni `_renderSuruStat` ile değişecek |
| `js/ui.js` | `updatePadokOzet()` fonksiyonu | Stat kartı bu işi üstleniyor |
| `js/api.js` | `_uremStatCache=null` invalidation satırı | `_suruStatCache={}` olacak |

---

## 5. Dokunulmayacaklar

- `stat_gebelik_ozet` RPC silinmez (ileride üreme sekmesi kullanabilir)
- Filtre chip'leri (`#filtre-strip`) olduğu gibi kalır — stat kartını etkilemez
- Arama çubuğu (`#srch`) olduğu gibi kalır
- `loadAnimals()` / `renderAnimals()` / `filterA()` mevcut mantığı değişmez

---

## 6. İleride (bu scope değil)

- Hastalık motoru: iyileşme oranı, antibiyotik etkinliği, laminit/mastitis oranları
- Multi-RPC mimari: istatistik motoru büyüyünce ayrı RPC'lere bölünür
- Dedicated istatistik sekmesi
- Dönem karşılaştırma (bu yıl vs geçen yıl)
- Sperma master tablosu
