# Gebelik İstatistik Kartı — Spec

**Tarih:** 2026-05-30
**Durum:** Taslak
**Bağlantı:** `.claude/ideas/alfa-istatistik.md`, `.claude/tasks/arge/task-037-istatistik-modulu.md`

## Amaç

Üreme sekmesinde sürü gebelik oranını ve kırılımlarını gösteren özet kart. Veterinerin tohumlama başarısını tek bakışta görmesi.

## Kapsam

- `stat_gebelik_ozet` RPC (PostgreSQL)
- Üreme sekmesinde stat kartı (tab üstü, sabit)
- Detay accordion (inek/düve, sperma top 5, deneme dağılımı)
- Filtre UI yok (MVP) — RPC parametreleri hazır, UI faz 2

## Kapsam Dışı

- Dedicated istatistik sekmesi
- Sperma master tablosu (fuzzy match)
- Maliyet hesabı
- Hastalık × üreme korelasyonu
- Filtre dropdown'ları (dönem, grup, sperma)

---

## 1. RPC: `stat_gebelik_ozet`

### İmza

```sql
CREATE OR REPLACE FUNCTION public.stat_gebelik_ozet(
  p_donem_baslangic date DEFAULT CURRENT_DATE - INTERVAL '365 days',
  p_donem_bitis     date DEFAULT CURRENT_DATE,
  p_kategori        text DEFAULT NULL,
  p_grup            text DEFAULT NULL,
  p_sperma          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
```

### Parametreler

| Parametre | Tip | Default | Açıklama |
|-----------|-----|---------|----------|
| `p_donem_baslangic` | date | today - 365 | Dönem başlangıcı |
| `p_donem_bitis` | date | today | Dönem bitişi |
| `p_kategori` | text | NULL | `'İnek'` veya `'Düve'` filtresi, NULL = hepsi |
| `p_grup` | text | NULL | Hayvan grubu filtresi |
| `p_sperma` | text | NULL | Normalize sperma adı filtresi |

### Düve / İnek Ayrımı

```sql
CASE
  WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
  WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
  WHEN h.grup ILIKE '%inek%' OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%' THEN 'İnek'
  ELSE 'Bilinmiyor'
END
```

Öncelik: grup adı > dogum kaydı > fallback. `dogum` tablosu doldukça otomatik iyileşir.

### Sperma Normalizasyonu

```sql
LOWER(TRIM(split_part(t.sperma, '|', 1)))
```

`"Armada red | 09856565 | Holstein"` → `"armada red"`
`"Darius"` → `"darius"`

### Gebelik Oranı Formülü

```sql
ROUND(
  100.0 * COUNT(*) FILTER (WHERE t.sonuc IN ('Gebe','Doğum Yaptı'))
  / NULLIF(COUNT(*) FILTER (WHERE t.sonuc != 'Bekliyor'), 0),
  1
)
```

Bekleyenler paydadan çıkar. Gebe + Doğum Yaptı = başarılı.

### Dönüş Formatı

```json
{
  "ozet": {
    "toplam": 85,
    "gebe": 22,
    "bos": 55,
    "abort": 0,
    "bekleyen": 4,
    "oran": 28.6
  },
  "kategori": [
    {"ad": "İnek", "toplam": 60, "gebe": 18, "oran": 30.0},
    {"ad": "Düve", "toplam": 25, "gebe": 4, "oran": 16.0}
  ],
  "sperma_top5": [
    {"ad": "armada red", "toplam": 20, "gebe": 5, "oran": 25.0},
    {"ad": "starred", "toplam": 12, "gebe": 4, "oran": 33.3}
  ],
  "deneme": [
    {"no": 1, "gebe": 8, "oran": 15.1},
    {"no": 2, "gebe": 7, "oran": 31.8},
    {"no": 3, "gebe": 4, "oran": 36.4}
  ]
}
```

### Tam SQL

```sql
CREATE OR REPLACE FUNCTION public.stat_gebelik_ozet(
  p_donem_baslangic date DEFAULT CURRENT_DATE - INTERVAL '365 days',
  p_donem_bitis     date DEFAULT CURRENT_DATE,
  p_kategori        text DEFAULT NULL,
  p_grup            text DEFAULT NULL,
  p_sperma          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH base AS (
    SELECT
      t.id,
      t.sonuc,
      t.deneme_no,
      LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
      CASE
        WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
        WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
        WHEN h.grup ILIKE '%inek%' OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%' THEN 'İnek'
        ELSE 'Bilinmiyor'
      END AS kategori
    FROM public.tohumlama t
    JOIN public.hayvanlar h ON h.id = t.hayvan_id
    WHERE h.cinsiyet = 'Dişi'
      AND t.tarih BETWEEN p_donem_baslangic AND p_donem_bitis
      AND (p_kategori IS NULL OR
           CASE
             WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
             WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
             WHEN h.grup ILIKE '%inek%' OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%' THEN 'İnek'
             ELSE 'Bilinmiyor'
           END = p_kategori)
      AND (p_grup IS NULL OR h.grup = p_grup)
      AND (p_sperma IS NULL OR LOWER(TRIM(split_part(t.sperma, '|', 1))) = LOWER(TRIM(p_sperma)))
  )
  SELECT jsonb_build_object(
    'ozet', jsonb_build_object(
      'toplam', COUNT(*),
      'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
      'bos',    COUNT(*) FILTER (WHERE sonuc = 'Boş'),
      'abort',  COUNT(*) FILTER (WHERE sonuc = 'Abort'),
      'bekleyen', COUNT(*) FILTER (WHERE sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                  / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
    ),
    'kategori', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', kategori,
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        GROUP BY kategori
      ) sub
    ),
    'sperma_top5', (
      SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', sperma_norm,
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        WHERE sonuc != 'Bekliyor'
        GROUP BY sperma_norm
        HAVING COUNT(*) >= 3
        ORDER BY ROUND(
                   100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                   / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC
        LIMIT 5
      ) sub
    ),
    'deneme', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'no', CASE WHEN deneme_no >= 3 THEN 3 ELSE deneme_no END,
          'gebe', COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran', ROUND(
                    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        GROUP BY CASE WHEN deneme_no >= 3 THEN 3 ELSE deneme_no END
      ) sub
    )
  ) INTO v_result
  FROM base;

  RETURN COALESCE(v_result, '{"ozet":{"toplam":0,"gebe":0,"bos":0,"abort":0,"bekleyen":0,"oran":null},"kategori":[],"sperma_top5":[],"deneme":[]}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_gebelik_ozet TO anon, authenticated;
```

---

## 2. UI: Stat Kartı

### Yerleşim

`ureme-body` div'inin **üstüne**, tab strip'in **altına** yeni bir `div#ureme-stat-card` eklenir. Tab değiştiğinde kart kaybolmaz — her zaman görünür.

```html
<!-- index.html: filter-strip'ten sonra, ureme-body'den önce -->
<div id="ureme-stat-card" style="display:none"></div>
<div id="ureme-body">...</div>
```

### Render Fonksiyonu

`ui.js` içinde `_renderUremeStat(container)` fonksiyonu:

1. `supabase.rpc('stat_gebelik_ozet', {})` çağrısı (default parametreler)
2. Sonucu parse et
3. Kartı render et

### Kart HTML (kapalı)

```html
<div class="stat-card" onclick="toggleUremeStat()">
  <div class="stat-header">
    <span>📊 Sürü Gebelik</span>
    <span class="stat-arrow">▼</span>
  </div>
  <div class="stat-summary">
    💉 85 tohumlama · ✅ 22 gebe · 📊 %29
  </div>
</div>
```

### Kart HTML (açık — accordion detay)

```html
<div class="stat-detail">
  <div class="stat-section">
    <div class="stat-row">🐄 İnek: 60 tohum · 18 gebe · <b>%30</b></div>
    <div class="stat-row">🐮 Düve: 25 tohum · 4 gebe · <b>%16</b></div>
  </div>
  <div class="stat-section">
    <div class="stat-section-title">🏆 Top Spermalar</div>
    <div class="stat-row">Starred — 12 tohum → <b>%33</b></div>
    <div class="stat-row">Armada red — 20 tohum → <b>%25</b></div>
    <div class="stat-row">PascoRed — 15 tohum → <b>%27</b></div>
  </div>
  <div class="stat-section">
    <div class="stat-section-title">🔢 Deneme Dağılımı</div>
    <div class="stat-row">1. deneme: 8 gebe (%15)</div>
    <div class="stat-row">2. deneme: 7 gebe (%32)</div>
    <div class="stat-row">3+. deneme: 7 gebe (%35)</div>
  </div>
</div>
```

### Stil

Mevcut `.hist-row` / `.card` stiline uyumlu. Yeni class'lar:

```css
.stat-card { background:var(--card); border-radius:8px; padding:10px 12px; margin-bottom:8px; cursor:pointer; }
.stat-header { display:flex; justify-content:space-between; align-items:center; font-weight:600; font-size:.85rem; }
.stat-summary { font-size:.8rem; color:var(--ink2); margin-top:4px; }
.stat-arrow { font-size:.7rem; color:var(--ink3); transition:transform .2s; }
.stat-card.open .stat-arrow { transform:rotate(180deg); }
.stat-detail { display:none; padding-top:8px; border-top:1px solid var(--border); margin-top:8px; }
.stat-card.open .stat-detail { display:block; }
.stat-section { margin-bottom:8px; }
.stat-section-title { font-size:.75rem; font-weight:600; color:var(--ink3); margin-bottom:4px; }
.stat-row { font-size:.8rem; color:var(--ink2); padding:2px 0; }
```

### Yükleme Zamanlaması

`loadUreme()` çağrıldığında `_renderUremeStat` de çağrılır — ancak tab switch'te tekrar çağrılmaz (cache). Sayfa ilk açılışta 1 kere RPC çağrısı.

```javascript
let _uremStatCache = null;

async function _renderUremeStat(container) {
  if (_uremStatCache) { _applyStatHtml(container, _uremStatCache); return; }
  const { data } = await supabase.rpc('stat_gebelik_ozet', {});
  if (data) { _uremStatCache = data; _applyStatHtml(container, data); }
}
```

Cache `pullTables` sonrası veya 5 dk sonra invalidate.

---

## 3. Etkilenen Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `supabase/migrations/` | Yeni migration: `stat_gebelik_ozet` RPC + GRANT |
| `supabase/migrations/99999999999999_ground_truth.sql` | Aynı RPC eklenir |
| `index.html` | `<div id="ureme-stat-card">` eklenir, CSS eklenir |
| `js/ui.js` | `_renderUremeStat`, `_applyStatHtml`, `toggleUremeStat`, cache mantığı |
| `js/utils/handlers.js` | Stat card toggle handler |

## 4. Değişmeyen

- Tohumlama formu, gebelik kontrolü, doğum kaydı
- Kızgınlık sekmesi
- Stok paneli, tedavi akışı
- IDB sync (RPC çağrısı direkt, tablo sync yok)

## 5. Edge Cases

- **Veri yok:** `oran: null` → kart gösterilir ama `📊 Veri yok` yazılır
- **Tüm bekliyor:** Payda 0 → `oran: null`
- **Sperma < 3 tohumlama:** Top 5'te gösterilmez (istatistiksel anlamsız)
- **Bilinmiyor kategorisi:** Gösterilir ama "Bilinmiyor" etiketi ile
- **dogum tablosu boşsa:** Tüm ayrım grup adından yapılır, sorunsuz çalışır

## 6. Gelecek Fazlar (bu spec değil)

- Filtre dropdown'ları (dönem, grup, sperma)
- Dedicated istatistik sekmesi
- Sperma master tablosu
- Maliyet hesabı
- Hastalık korelasyonu
