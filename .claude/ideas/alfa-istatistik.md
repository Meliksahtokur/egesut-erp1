# Alfa İstatistik Modülü — Mimari Analiz

**Oluşturuldu:** 2026-05-26  
**Tetikleyen:** #37 gebelik % hesaplama  
**Durum:** Fikir / Mimari karar bekleniyor

---

## Soru: Hangi Yaklaşım?

Kullanıcının önerdiği iki yol:

| | Yol 1 — Merkezi İstatistik Modülü | Yol 2 — Modül-Gömülü İstatistik |
|---|---|---|
| **Vizyon** | Her şeyin istatistiği bir yerde, çapraz analiz mümkün | Her ekran kendi istatistiğini taşır |
| **Bugün maliyeti** | Yüksek (altyapı + UI tab) | Düşük (birkaç sorgu) |
| **Yarın maliyeti** | Düşük (veri zaten var, yeni ekran kolaylaşır) | Yüksek (her modülde tekrar) |
| **Çapraz analiz** | ✅ Doğal (sperma × hastalık × maliyet) | ❌ Zor, duplicate mantık |
| **UX** | Ayrı sekme, odaklanmış | Bağlamsal, kullanıcı neredeyse görsün |

**Sonuç:** İkisi birbirini dışlamıyor. Doğru mimari şu:

> **Veri katmanı Yol 1 gibi** (merkezi PostgreSQL view'lar)  
> **Sunum katmanı Yol 2 gibi** (bağlamsal gösterim)

Bugün ayrı bir "İstatistik" sekmesi açmak zorunda değiliz — ama view'lar hazır olursa yarın 1 günde sekme olur.

---

## Mimari Karar: Hesaplama Nerede?

**Kesin cevap: PostgreSQL.** (ERP mimari kuralı gereği, frontend güvenilmez.)

```
UI Layer
  └── stat RPC'yi çağırır, sonucu görüntüler
      └── filtre parametreleri gönderir (donem, grup, sperma)

PostgreSQL Layer
  ├── v_stat_gebelik          → temel gebelik istatistikleri
  ├── v_stat_sperma           → boğa/sperma performansı
  ├── v_stat_laktasyon        → buzağı sayısı × tohumlama korelasyonu
  ├── v_stat_maliyet          → gebelik başı maliyet
  └── stat_gebelik_ozet(...)  → filtreli RPC
```

Frontend asla:
- `gebe_orani = gebe_sayisi / toplam * 100` hesaplamaz
- Array'i döngüye sokmaz
- Çapraz join yapmaz

---

## Veri Modeli Analizi (Mevcut)

### Gebelik % için hazır olan:

```
tohumlama
├── hayvan_id     → hayvanlar.cinsiyet, .grup
├── tarih         → dönem filtresi
├── sperma        → boğa analizi
├── hekim_id      → hekim performansı (ileride)
├── sonuc         → Bekliyor | Gebe | Boş | Doğum Yaptı | Abort
├── deneme_no     → kaçıncı tohumda gebe kaldı
└── ek_uygulamalar → maliyet hesabı için (GnRH, PG dozu)

dogum (anne_id = hayvan.id)
└── COUNT(*) → düve/inek ayrımı + kaçıncı buzağı
```

### Kritik türetme: Düve vs İnek

`hayvanlar` tablosunda "düve" kolonu yok. Türetilmeli:

```sql
-- Düve: Dişi, hiç doğum kaydı yok
-- İnek: Dişi, ≥1 doğum kaydı var

CASE 
  WHEN EXISTS (SELECT 1 FROM dogum WHERE anne_id = h.id) THEN 'İnek'
  ELSE 'Düve'
END as kategori
```

> ⚠️ dogum tablosu şu an boş → bu ayrım çalışmaz. İleride dolunca otomatik çalışır.

### Kaçıncı buzağı analizi:

```sql
(SELECT COUNT(*) FROM dogum WHERE anne_id = h.id) as buzagi_sayisi
```

### Mevcut eksikler:

| Eksik | Etki | Çözüm |
|-------|------|-------|
| `dogum` tablosu boş | Düve/inek ayrımı yok, buzağı sayısı 0 | Doğum modülü kullanıma girdikçe dolar |
| Sperma adı `text` (serbest giriş) | "Darius", "darius", "DARİUS" farklı sayılır | Normalizasyon veya sperma master tablosu |
| Hekim performansı | `hekim_id` var ama analizde kullanılmıyor | View'a eklenebilir |
| Maliyet verisi | `ek_uygulamalar` var ama fiyat yok | Stok fiyat kolonu eklenirse otomatik gelir |

---

## Önerilen View Mimarisi

### 1. `v_stat_gebelik` — Temel View

```sql
CREATE OR REPLACE VIEW public.v_stat_gebelik AS
SELECT
  t.sperma,
  t.deneme_no,
  h.grup,
  CASE 
    WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
    ELSE 'Düve'
  END                                                            AS kategori,
  (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id)  AS buzagi_sayisi,
  COUNT(*)                                                        AS toplam_tohumlama,
  COUNT(*) FILTER (WHERE t.sonuc != 'Bekliyor')                  AS kapali_tohumlama,
  COUNT(*) FILTER (WHERE t.sonuc IN ('Gebe','Doğum Yaptı'))      AS gebe_sayisi,
  COUNT(*) FILTER (WHERE t.sonuc = 'Boş')                        AS bos_sayisi,
  COUNT(*) FILTER (WHERE t.sonuc = 'Abort')                       AS abort_sayisi,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE t.sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*) FILTER (WHERE t.sonuc != 'Bekliyor'), 0),
    1
  )                                                               AS gebelik_orani,
  t.tarih
FROM public.tohumlama t
JOIN public.hayvanlar h ON h.id = t.hayvan_id
WHERE h.cinsiyet = 'Dişi'
GROUP BY t.sperma, t.deneme_no, h.grup,
         (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id),
         (CASE WHEN EXISTS (SELECT 1 FROM public.dogum d2 WHERE d2.anne_id = h.id) THEN 'İnek' ELSE 'Düve' END),
         t.tarih;
```

> Bu view çok granüler — RPC içinde aggregate yapılacak.

### 2. `stat_gebelik_ozet(...)` — Filtreli RPC

```sql
CREATE OR REPLACE FUNCTION public.stat_gebelik_ozet(
  p_donem_baslangic  date    DEFAULT CURRENT_DATE - INTERVAL '365 days',
  p_donem_bitis      date    DEFAULT CURRENT_DATE,
  p_kategori         text    DEFAULT NULL,  -- 'İnek' | 'Düve' | NULL = hepsi
  p_grup             text    DEFAULT NULL,
  p_sperma           text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    -- Genel özet
    'ozet', jsonb_build_object(
      'toplam_tohumlama',  COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
      'gebe_sayisi',       COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
      'bos_sayisi',        COUNT(*) FILTER (WHERE sonuc = 'Boş'),
      'abort_sayisi',      COUNT(*) FILTER (WHERE sonuc = 'Abort'),
      'bekleyen_sayisi',   COUNT(*) FILTER (WHERE sonuc = 'Bekliyor'),
      'gebelik_orani',     ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                             / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
    ),
    -- Kategori kırılımı (inek / düve)
    'kategori_kirilimlari', (
      SELECT jsonb_agg(jsonb_build_object(
        'kategori', kategori,
        'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
        'gebe', COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
        'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                  / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
      )) FROM (...subquery...)
    ),
    -- Sperma performansı
    'sperma_karsilastirma', (
      SELECT jsonb_agg(jsonb_build_object(
        'sperma', sperma,
        'toplam', ...,
        'oran', ...
      ) ORDER BY oran DESC)
    ),
    -- Deneme sayısı dağılımı (1. denemede gebe, 2. denemede, ...)
    'deneme_dagilimi', (
      SELECT jsonb_agg(jsonb_build_object(
        'deneme_no', deneme_no,
        'gebe_sayisi', ...,
        'oran', ...
      ) ORDER BY deneme_no)
    )
  ) INTO v_result
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  CROSS JOIN LATERAL (
    SELECT CASE WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) 
           THEN 'İnek' ELSE 'Düve' END AS kategori
  ) k
  WHERE h.cinsiyet = 'Dişi'
    AND t.tarih BETWEEN p_donem_baslangic AND p_donem_bitis
    AND (p_kategori IS NULL OR k.kategori = p_kategori)
    AND (p_grup IS NULL OR h.grup = p_grup)
    AND (p_sperma IS NULL OR t.sperma = p_sperma);

  RETURN v_result;
END;
$$;
```

---

## İleride Genişleme Haritası

### Faz 1 — Gebelik İstatistiği (şimdi yapılabilir)
- `stat_gebelik_ozet` RPC
- Üreme sekmesinde veya sürü dashboard'ında tek kart: "Sürü Gebelik %: 68%"
- Filtre: dönem / inek-düve / padok

### Faz 2 — Sperma & Boğa Analizi
- `stat_sperma_performans` RPC
- Sperma seçimi sırasında "Bu boğanın gebelik oranı: %72" göster
- Mevcut sperma adı normalizasyonu gerekir (master tablo veya fuzzy match)

### Faz 3 — Maliyet Analizi
- Stok fiyat kolonu eklenince `ek_uygulamalar` maliyeti hesaplanabilir
- `gebelik_maliyeti = SUM(sperma_fiyati + gnrh_fiyati + pg_fiyati) / gebe_sayisi`

### Faz 4 — Hastalık × Üreme Korelasyonu
- Cases tablosundaki `disease_name` ile tohumlama başarısı çapraz
- "Endometrit geçirmiş ineklerin gebelik oranı %42 (sürü ortalaması %68)"

### Faz 5 — Hekim Performansı
- `hekim_id` tohumlama tablosunda mevcut, analizde kullanılmıyor
- Hekim bazlı gebelik oranı: "Dr. X: %72, Dr. Y: %58"
- `v_ureme_dongusu` view'ına `hekim_id` kolonu eklenirse cycle bazlı hekim performansı çıkar

### Faz 6 — İstatistik Sekmesi (dedicated tab)
- Tüm view'lar hazır olunca 1 günde sekme açılır
- Dönem karşılaştırma: Bu ay vs geçen ay, bu yıl vs geçen yıl
- Export (CSV/PDF) ileride

### Faz 7 — Materialized View (performans gerekirse)
- 234 kayıt için gereksiz, binlerce kayda ulaşınca değerlendirilecek
- `v_ureme_dongusu` → `mv_ureme_dongusu` + REFRESH trigger

---

## Kısa Vadeli Plan (#37 için minimum)

**Bugün yapılabilecek (2-3 task):**

```
Task 1 — stat_gebelik_ozet RPC (PostgreSQL)
  → Filtre: dönem (varsayılan: son 365 gün)
  → Çıktı: gebelik_orani, inek_orani, düve_orani, top 3 sperma, deneme dağılımı

Task 2 — Üreme sekmesi stat kartı (UI)
  → Mevcut _uremeKizginlik fonksiyonunun yanına
  → Tek RPC çağrısı, basit kart: "💉 Tohumlama: 47 | ✅ Gebe: 32 | 📊 %68"
  → Dokunulabilir → detay accordion açılır

Task 3 — Ground truth + commit
```

**Şimdilik ERTELENENLER:**
- Dedicated istatistik sekmesi
- Sperma normalizasyonu
- Maliyet hesabı (fiyat verisi yok)
- Hastalık korelasyonu

---

## Sperma Normalizasyon Sorunu

Şu an `tohumlama.sperma` serbest text. Gebelik analizi için aynı boğanın farklı yazılmışları ayrı sayılır:

```
"Darius" → 12 tohumlama, %75
"DARIUS" → 3 tohumlama, %66
"darius bull" → 1 tohumlama, %100
```

**Çözüm seçenekleri:**
1. **Master tablo** (sperma_stok zaten var) → tohumlama.sperma_stok_id FK ekle
2. **LOWER() + TRIM()** normalize → hızlı ama "Darius" vs "ABS Darius" yine ayrı
3. **Sonraya bırak** — ilk gebelik % için yeterince doğru

Öneri: Şimdilik `LOWER(TRIM(t.sperma))` normalize et, sperma master tablo faz 2'ye bırak.

---

## Düve / İnek Ayrımı (önemli not)

`dogum` tablosu şu an boş → tüm dişiler "Düve" görünür.

**Geçici çözüm:** `hayvanlar.grup` değerinden türet:
```sql
CASE 
  WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
  WHEN h.grup ILIKE '%inek%' OR h.grup ILIKE '%sagmal%' THEN 'İnek'
  WHEN EXISTS (SELECT 1 FROM dogum d WHERE d.anne_id = h.id) THEN 'İnek'
  ELSE 'Bilinmiyor'
END
```

`dogum` tablosu doldukça ikinci WHEN devreye girer ve grup adı bağımsız çalışır.

---

## Bağlantılı Fikirler

- `ureme-zeka.md` → 260-gün çıkarım, buzağı sayısı, laktasyon döngüsü — stat modülünde kullanılabilir
- `dashboard-aktif-vakalar.md` → dashboard'a stat kartı eklenebilir
- `kural-motoru-rule-engine.md` → istatistik tabanlı uyarı: "Bu inek 3 kez boş kaldı → önlem öner"

---

## Bekleyen: Tarih Aralığı Filtresi (Seçenek 3)

**Tarih:** 2026-05-30
**Durum:** Not alındı, UI sonra yapılır

stat_suru_ozet RPC'ye `p_donem_baslangic date` ve `p_donem_bitis date` parametreleri eklenecek.
Kullanıcı belirli tarih aralığında istatistik görebilecek (örn: "Ocak-Mart 2026 dönemi").
RPC tarafı kolay (WHERE t.tarih BETWEEN), UI tarafı date picker gerektirir — şimdilik ertelendi.
stat_gebelik_ozet zaten bu parametrelere sahip, stat_suru_ozet'e de eklenecek.

---

## Özet Karar

| Soru | Yanıt |
|------|-------|
| Backend mi, frontend mi? | Kesinlikle backend (PostgreSQL view + RPC) |
| Merkezi mi, gömülü mü? | Veri katmanı merkezi, sunum bağlamsal |
| İstatistik modülü şimdi mi? | Veri katmanı şimdi, UI sekmesi faz 2-3 |
| #37 minimum MVP? | 1 RPC + üreme sekmesinde stat kartı |
| Genişletilebilir mi? | Evet — her yeni view yeni boyut ekler |
| Bugün engel ne? | dogum tablosu boş (düve/inek ayrımı), sperma text normalizasyonu |
