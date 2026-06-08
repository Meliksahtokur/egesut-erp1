# EgeSüt ERP — İstatistik Hesaplama Hatası Araştırması

**Tarih:** 2026-06-01  
**Durum:** ✅ Araştırma tamamlandı

---

## 1. Dünkü SQL Değişiklikleri Özeti

30 Mayıs - 1 Haziran arasında **11 commit** migration dosyalarında:

| Tarih | Commit | Değişiklik |
|-------|--------|------------|
| 31 May 03:44 | `d70953c` | **v_ureme_dongusu view** — cycle detection (yeni migration: `20260530210000_v_ureme_dongusu.sql`) |
| 31 May 03:56 | `d65083e` | **stat_suru_ozet v2** — cycle-bazlı + hayvan-bazlı sentez (yeni migration: `20260530220000_stat_suru_ozet_v2.sql`) |
| 31 May 15:08 | `6dd807e` | ground_truth sync — Faz A/B/C |
| 31 May 16:09 | `be09073` | v_eligible küçük düve grubu filtresi |
| 31 May ~ | `9881f39` | Sessiz hayvan yaş filtresi |
| 31 May ~ | `a8c5075` | Faz C — v_eligible + sessiz hayvan RPC |
| 31 May ~ | `b1ef65e` | Faz B — VWP enforcement |
| 31 May ~ | `92abd5a` | Faz A — 42-gün kuralı |
| 1 Haz | `83acb68` | Buzağı toplu giriş |
| 30 May | `d65083e` | stat_gebelik_ozet migration (`20260530180000_stat_gebelik_ozet.sql`) |

**Kritik migrationlar:**
- `20260530210000_v_ureme_dongusu.sql` — cycle view (31 May)
- `20260530220000_stat_suru_ozet_v2.sql` — cycle-bazlı istatistik RPC (31 May)
- `20260530180000_stat_gebelik_ozet.sql` — tohumlama-bazlı istatistik RPC (30 May)

---

## 2. Mevcut Hesaplamanın Neden Yanlış Olduğu

### 2.1 v_ureme_dongusu — Cycle Tespit Mekanizması

View iki aşamalı çalışır:

**Aşama 1 — numbered CTE:**
Her tohumlama kaydına `cycle_no` atanır. Cycle sınırı: `deneme_no = 1`

```sql
SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
  OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no
        ROWS UNBOUNDED PRECEDING) AS cycle_no
```

Her `deneme_no=1` yeni bir cycle başlatır. Örneğin:
```
hayvan X: deneme_no=[1,2,3,4,5,6] → cycle_no=[1,1,1,1,1,1]  (tek cycle!)
hayvan Y: deneme_no=[1,2,1,2,3]   → cycle_no=[1,1,2,2,2]    (iki cycle)
```

**Sorun:** Eğer bir hayvanın tüm tohumlamaları `deneme_no=1` ile başlayıp artarak gidiyorsa (ki doğal akış budur — yeni cycle'a geçmek deneme_no sıfırlamaz), **tüm tohumlamalar tek bir cycle'da toplanır.**

**Aşama 2 — Gruplama ve bool_or:**
```sql
CASE
  WHEN bool_or(sonuc IN ('Gebe','Doğum Yaptı')) THEN 'Gebe'
  WHEN bool_or(sonuc = 'Abort')                 THEN 'Abort'
  WHEN bool_or(sonuc = 'Bekliyor')              THEN 'Bekliyor'
  ELSE 'Boş'
END AS sonuc
```

Cycle içinde **en az 1 tane** "Gebe" veya "Doğum Yaptı" varsa → tüm cycle "Gebe" sayılır.

### 2.2 Sayısal Örnek — Hata Büyüklüğü

Bir hayvanın tohumlama geçmişi:
```
deneme_no: 1(boş)  2(boş)  3(boş)  4(boş)  5(boş)  6(gebe)
cycle_no:  1       1       1       1       1       1
```

**v_ureme_dongusu çıktısı:** 1 cycle, sonuc="Gebe"  
**Kaybolan:** 5 adet "Boş" kayıt

Tüm veritabanında:
- **Toplam tohumlama:** 245 (aktif dişiler)
- **"Boş" kayıt:** 122 adet
- **Cycle view'da "Boş" cycle sayısı:** 4
- **Kaybolan "Boş" sayısı:** 122 - 4 = **118 Boş kayıt kayboluyor**

### 2.3 stat_suru_ozet — İkinci Katman Hata

`hayvan_ozet` bölümü:
```sql
'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor')
'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe')
'oran',   gebe / toplam
```

Her hayvan **sadece 1 kere** sayılır. En son cycle'ı "Gebe" olan hayvan → "Gebe" sayılır. Kaç tane "Boş" tohumlama yapmış olduğu önemsizdir.

**Canlı veri:**
```
hayvan_ozet.oran = 49 / 53 = %92.5
```

Bu **doğru bir gebelik oranı değildir**. Bu "son cycle'ı gebe olan hayvanlar / halen tohumlanan hayvanlar" oranıdır — her hayvanı binary (gebe/boş) sınıflandırır, toplam tohumlama sayısını hesaba katmaz.

### 2.4 42-Gün Filtresinin Etkisi

stat_suru_ozet'de:
```sql
AND v.baslangic < CURRENT_DATE - 42
```

Başlangıcı 42 günden eski olmayan cycle'lar **tamamen dışlanır**. Bu da son 42 günde yapılan tohumlamaları yok sayar. Bu filtre, "son dönem" (p_son_donem=true) modunda cycle seçimini de etkiler.

---

## 3. Ham Veri Sayıları

### 3.1 Tüm Tohumlama Sonuç Dağılımı

| Sonuç | Adet | % |
|-------|------|---|
| Boş | 122 | %50.2 |
| Doğum Yaptı | 60 | %24.7 |
| Gebe | 35 | %14.4 |
| Bekliyor | 27 | %11.1 |
| Abort | 1 | %0.4 |
| **Toplam** | **245** | **100%** |

**Tohumlama-bazlı gebelik oranı:** (60+35) / (245-27) = 95/218 = **%43.6**

### 3.2 Deneme No Dağılımı (Aktif Dişiler)

| Deneme | Adet |
|--------|------|
| 1 | 127 |
| 2 | 62 |
| 3 | 30 |
| 4 | 13 |
| 5 | 6 |
| 6 | 5 |
| 7 | 2 |
| **Toplam** | **245** |

- Tohumlanan aktif dişi hayvan: **73**
- Ortalama deneme sayısı: **1.9**
- Maksimum deneme: **7**

### 3.3 stat_gebelik_ozet (Tohumlama-Bazlı, Doğru)

| Metrik | Değer |
|--------|-------|
| Toplam (Bekliyor hariç) | 199 |
| Gebe/Doğum | 90 |
| Boş | 108 |
| Abort | 1 |
| Bekliyor | 27 |
| **Oran** | **%45.2** |

*(Not: 365 günlük varsayılan filtre uygular — tüm zamanların oranı %43.6)*

**Kategori bazlı:**
| Kategori | Toplam | Gebe | Oran |
|----------|--------|------|------|
| İnek | 190 | 88 | %46.3 |
| Düve | 9 | 2 | %22.2 |

### 3.4 stat_suru_ozet (Cycle-Bazlı, Yanlış)

| Metrik | Değer |
|--------|-------|
| **hayvan_ozet.oran** | **%92.5** ← YANLIŞ |
| cycle_ozet.oran | %93.8 |
| cycle_ozet.basarili_cycle | 60 |
| cycle_ozet.basarisiz_cycle | 4 |
| cycle_ozet.toplam_cycle | 64 |

---

## 4. Doğru Metrik SQL Taslağı

Henüz uygulamaya gerek yok — sadece taslak.

### 4.1 Yaklaşım

Doğru metrik şu mantıkla hesaplanmalı:

1. **Tohumlama-bazlı** (cycle değil) — her tohumlama bir "deneme"dir
2. **Hayvanın tüm geçmişi** — en son durumu değil
3. **Kategori bazlı** (İnek/Düve ayrı)
4. **Deneme bazlı kırılım**

### 4.2 SQL Taslağı

```sql
-- DOĞRU GEBELİK ORANI (tohumlama-bazlı)
-- Her tohumlama kaydını ayrı değerlendir
-- Cycle kavramı kullanma — sadece deneme_no'ya göre kır

WITH base AS (
  SELECT
    t.id,
    t.hayvan_id,
    t.sonuc,
    t.deneme_no,
    CASE
      WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
      WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
      ELSE 'İnek'
    END AS kategori,
    h.id AS hayvan_id_check
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  WHERE h.cinsiyet = 'Dişi'
    AND h.durum = 'Aktif'
    AND h.kisir IS NOT TRUE
)
-- GENEL ORAN
SELECT
  'Genel' AS kategori,
  COUNT(*) FILTER (WHERE sonuc != 'Bekliyor') AS toplam,
  COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')) AS gebe,
  ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) AS oran,
  COUNT(*) FILTER (WHERE sonuc = 'Bekliyor') AS bekleyen
FROM base
UNION ALL
-- KATEGORİ BAZLI
SELECT
  kategori,
  COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
  COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
  ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1),
  COUNT(*) FILTER (WHERE sonuc = 'Bekliyor')
FROM base
GROUP BY kategori;
```

### 4.3 Deneme Bazlı Oran (First Service Conception Rate)

```sql
-- 1. denemede gebe kalanlar
SELECT
  '1. Deneme' AS deneme,
  COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')) AS gebe,
  COUNT(*) FILTER (WHERE sonuc != 'Bekliyor') AS toplam,
  ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) AS oran
FROM tohumlama
WHERE deneme_no = 1

UNION ALL

-- 2. denemede gebe kalanlar (1.de boş kalanlar içinden)
SELECT
  '2. Deneme' AS deneme,
  COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
  COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
  ROUND(100.0 * ...)
FROM tohumlama
WHERE deneme_no = 2

UNION ALL

-- 3+ deneme (gruplanmış)
SELECT '3+ Deneme', ... FROM tohumlama WHERE deneme_no >= 3
```

### 4.4 "Bekliyor" Yönetimi

- Son tohumlama > 90 gün önce ve sonucu "Bekliyor" ise → "Boş" say
- Son tohumlama ≤ 90 gün önce ve sonucu "Bekliyor" ise → denominatörden çıkar

```sql
CASE
  WHEN sonuc = 'Bekliyor' AND CURRENT_DATE - tarih > 90 THEN 'Boş'
  WHEN sonuc = 'Bekliyor' AND CURRENT_DATE - tarih <= 90 THEN 'Bekliyor'
  ELSE sonuc
END AS etkin_sonuc
```

### 4.5 Hayvan-Bazlı Oran (Alternatif Görünüm)

Her hayvanın **son tohumlama sonucu** bazında:
- Toplam tohumlanan hayvan: **73**
- Sonucu "Gebe" veya "Doğum Yaptı" olan: sayısı hesaplanacak
- Bu oran yaklaşık **~%50-60** civarında olmalı (%92.5 değil!)

(Not: Her hayvan bir kere sayıldığı için bu metrik düşük riskli hayvanlarda daha iyimser görünebilir — yine de %92.5 olamaz.)

---

## 5. Sonuç ve Öneriler

| Sorun | Şiddet | Açıklama |
|-------|--------|----------|
| v_ureme_dongusu `bool_or` hatası | 🔴 Kritik | Cycle içinde bir "Gebe" varsa tüm cycle gebe sayılır → 118 "Boş" kayıt yok olur |
| stat_suru_ozet `DISTINCT hayvan_id` | 🟡 Yüksek | Her hayvanı 1 kere sayar → binary sınıflandırma, toplam tohumlama sayısını gizler |
| 42-gün filtresi | 🟡 Orta | Son 42 gündeki cycle'ları tamamen atlar |
| cycle sınırı `deneme_no=1` | 🟠 Orta | Normal akışta nadiren sıfırlanır → tüm tohumlamalar tek cycle'da |

**Doğru oran:** Tohumlama-bazlı **%43.6 — %45.2** (kullanılan fonksiyona bağlı)  
**Yanlış oran:** Cycle/hayvan-bazlı **%92.5** (dashboard'da görünen)

**Öneriler:**
1. `stat_suru_ozet` cycle-bazlı metriklerini düzelt — ya tohumlama-bazlıya geç ya da cycle tanımını revize et
2. `stat_gebelik_ozet` doğru çalışıyor — dashboard bu fonksiyonu kullanmalı
3. `v_ureme_dongusu` view'ı ya düzeltilmeli (gerçek cycle tespiti) ya da kullanımdan kaldırılmalı
