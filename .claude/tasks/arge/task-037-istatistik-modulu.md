# Task #37 — Gebelik % & İstatistik Modülü

**Durum:** ✅ TAMAMLANDI (MVP — 2026-05-30)  
**Öncelik:** Orta  
**Bağımlılık:** dogum tablosu veri girişiyle dolar → düve/inek ayrımı otomatik iyileşir  
**Tamamlanan:** stat_gebelik_ozet RPC + üreme stat kartı (accordion detay). Filtre UI, dedicated sekme faz 2.

---

## Ne Yapılacak

Tohumlama verilerinden gebelik oranı hesaplama + genişletilebilir istatistik altyapısı.

**Detaylı mimari analiz:** `.claude/ideas/alfa-istatistik.md`

---

## MVP Scope (#37 minimum)

### Task A — `stat_gebelik_ozet` RPC (PostgreSQL)

Filtreli gebelik istatistiği döndürür:

```
stat_gebelik_ozet(
  p_donem_baslangic date DEFAULT today-365,
  p_donem_bitis     date DEFAULT today,
  p_kategori        text DEFAULT NULL,  -- 'İnek' | 'Düve'
  p_grup            text DEFAULT NULL,
  p_sperma          text DEFAULT NULL
) → jsonb
```

Döndürdükleri:
- `ozet.gebelik_orani` — toplam %
- `ozet.gebe_sayisi`, `bos_sayisi`, `bekleyen_sayisi`
- `kategori_kirilimlari` — inek vs düve ayrımı
- `sperma_karsilastirma` — her boğanın başarı oranı (LOWER/TRIM normalize)
- `deneme_dagilimi` — 1. denemede, 2. denemede, 3+. denemede gebe kalanlar

Referans: `alfa-istatistik.md` → "Önerilen View Mimarisi" bölümü

### Task B — UI Stat Kartı

Üreme sekmesinde (veya sürü dashboard'ında) küçük kart:

```
💉 Tohumlama: 47  |  ✅ Gebe: 32  |  📊 %68  |  [Detay ▼]
```

Detay accordion: inek/düve kırılımı + top 3 sperma tablosu

### Task C — Ground truth + commit

---

## Bilinen Kısıtlar

- `dogum` tablosu boş → düve/inek ayrımı şimdi `hayvanlar.grup` adından türetilir
- `sperma` serbest text → `LOWER(TRIM())` ile normalize et (master tablo faz 2)
- Maliyet hesabı: stok fiyat kolonu eklenince gelir (faz 3)

---

## Gelecek Fazlar (bu task değil)

- Faz 2: Sperma master tablosu, boğa profili
- Faz 3: Gebelik maliyeti (ek uygulama + sperma fiyatı)
- Faz 4: Hastalık × üreme korelasyonu
- Faz 5: Dedicated istatistik sekmesi + dönem karşılaştırma

Tüm detay: `.claude/ideas/alfa-istatistik.md`
