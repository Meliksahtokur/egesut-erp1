# TASK-046 — İstatistik Altyapısına `iptal` Filtresi Ekleme

**Durum:** 📋 PLANLAMA (pending) — 2026-06-16 açıldı
**Öncelik:** Orta
**Tarih:** 2026-06-16
**Bağlam:** Küpe 150 vakası (bakınız `BLACKBOARD.md` / session logları)

---

## Problem

`tohumlama` tablosunda `iptal boolean DEFAULT false` kolonu var (ground_truth line 45, 62), ama **hiçbir istatistik bileşeni bu kolonu filtrelemiyor**. Sonuç: iptal edilen tohumlamalar gebelik oranı, cycle sayısı, bekleyen sayısı gibi tüm istatistikleri kirletiyor.

`tohumlama_cycle_gorevcil_iptal` trigger fonksiyonu (line 965-985) `iptal=true` yaptığında görevleri iptal ediyor ama istatistik view/fonksiyonlarını ETKİLEMİYOR.

### Doğrulama (Küpe 150 vakası, 2026-06-15)

```
1) gebelik_ozet_view       →  iptal filtresi YOK
2) v_ureme_dongusu         →  iptal filtresi YOK, cycle_no dahil ediyor
3) stat_suru_ozet (SQL)    →  iptal filtresi YOK
4) stat-hesapla (Edge Fn)  →  iptal filtresi YOK (grep -c iptal = 0)
```

**Senaryo:** 9. tohumlama `iptal=true` yapılırsa `v_ureme_dongusu` yeni cycle olarak sayar → küpe 150 için 1 Gebe + 1 Bekliyor (iptal) = %50 yanlış gebelik oranı.

---

## Etkilenen Bileşenler

| # | Bileşen | Dosya / Konum | Mevcut Davranış |
|---|---------|---------------|-----------------|
| 1 | `gebelik_ozet_view` | `ground_truth.sql:1486-1498` | Sadece tarih filtresi, iptal YOK |
| 2 | `v_ureme_dongusu` | `ground_truth.sql:7794-7838` | `cinsiyet='Dişi' AND kisir IS NOT TRUE`, iptal YOK |
| 3 | `hayvan_durum_analizi` | `ground_truth.sql:1434` | (Kontrol gerekli) |
| 4 | `tohumlanabilir_hayvanlar` | `ground_truth.sql:6086, 7185` | (Kontrol gerekli) |
| 5 | `stat_suru_ozet` (SQL fn) | `ground_truth.sql:7829+` | tohumlama sorguları iptal filtresiz |
| 6 | `stat-hesapla` (Edge Fn) | `supabase/functions/stat-hesapla/index.ts` | `disiTohumlamalar` filtresinde iptal YOK |

---

## Yapılacaklar

### Aşama 1 — SQL View'lar (`ground_truth.sql`)

Tüm tohumlama kullanan view'lara `AND iptal IS NOT TRUE` (veya `AND iptal = false`) ekle:

```sql
-- gebelik_ozet_view
CREATE OR REPLACE VIEW public.gebelik_ozet_view AS
SELECT
  COUNT(*) FILTER (WHERE sonuc = 'Gebe')        AS gebe_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Bekliyor')    AS bekleyen_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Abort')       AS abort_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Doğum Yaptı') AS dogum_yapti_sayisi,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*), 0), 1
  ) AS gebelik_orani_pct
FROM public.tohumlama
WHERE tarih >= CURRENT_DATE - interval '12 months'
  AND iptal IS NOT TRUE;  -- ✅ YENİ
```

`v_ureme_dongusu` için — `numbered` CTE'de veya ana FROM'da filtre:
```sql
FROM public.tohumlama t
JOIN public.hayvanlar h ON h.id = t.hayvan_id
WHERE h.cinsiyet = 'Dişi'
  AND h.kisir IS NOT TRUE
  AND t.iptal IS NOT TRUE  -- ✅ YENİ
```

### Aşama 2 — `stat_suru_ozet` SQL Fonksiyonu

Fonksiyon içindeki tüm `FROM public.tohumlama` veya `SELECT ... FROM public.tohumlama` sorgularına `AND iptal IS NOT TRUE` ekle. Veya tek satırda:
- Eğer performans kritikse, iç sorguları `WITH iptal_filtreli AS (SELECT * FROM tohumlama WHERE iptal IS NOT TRUE)` ile ön filtrele.

### Aşama 3 — Edge Function `stat-hesapla`

`/root/egesut-erp1/supabase/functions/stat-hesapla/index.ts:106` civarı:

```typescript
// ÖNCEKİ
const disiTohumlamalar = tohumlamalar.filter((t) => {
  const h = hayvanMap.get(t.hayvan_id);
  return h && h.cinsiyet === "Dişi" && filteredIds.has(t.hayvan_id);
});

// YENİ
const disiTohumlamalar = tohumlamalar.filter((t) => {
  const h = hayvanMap.get(t.hayvan_id);
  return h && h.cinsiyet === "Dişi" && filteredIds.has(t.hayvan_id) && !t.iptal;
});
```

`Tohumlama` interface'ine `iptal: boolean` alanı ekle (line 51-58 civarı).

### Aşama 4 — Migration

Yeni migration dosyası oluştur:
- Versiyon: `20260616000001_istatistik_iptal_filtresi.sql`
- İçerik: `CREATE OR REPLACE VIEW ...` (mevcut view'ların güncel hali + iptal filtresi)
- Deploy: `supabase_migrate` MCP ile ayrıca çalıştır (git push yetmez)

### Aşama 5 — Doğrulama

- `iptal=true` olan bir tohumlama oluştur ve istatistiklerde sayılmadığını doğrula
- Küpe 150 vakasını simüle et: 9. tohumlama `iptal=true` olsaydı, `v_ureme_dongusu` 1 cycle (sadece 8. Gebe) görmeliydi
- `ground_truth.sql`'i regen et (33/138/12 birebir eşleşme prensibi)

---

## Kabul Kriterleri

- [ ] `gebelik_ozet_view` `iptal=true` olan tohumlamaları saymıyor
- [ ] `v_ureme_dongusu` `iptal=true` olan tohumlamaları cycle'a dahil etmiyor
- [ ] `stat_suru_ozet` fonksiyonu iptal filtreli
- [ ] `stat-hesapla` Edge Function TypeScript'i iptal filtreli
- [ ] Yeni migration deploy edildi
- [ ] `ground_truth.sql` regen edildi
- [ ] Test: 1 adet `iptal=true` kayıt oluştur, istatistiklerde görünmediğini doğrula
- [ ] Test: küpe 150 simülasyonu — 1 cycle (8. Gebe) görünmeli
- [ ] Commit mesajı: `fix(db): istatistik view'larına iptal filtresi ekle`

---

## Referanslar

- Küpe 150 vakası session logu: `MEMORY.md` Part 18, `guides/projects/egesut-erp1.md` SURU-TAKIP bölümü
- Ground truth: `supabase/migrations/99999999999999_ground_truth.sql`
- Edge function: `supabase/functions/stat-hesapla/index.ts`
- Domain rules: `.claude/domain-rules.md`
- İlgili task #37: `tasks/arge/task-037-istatistik-modulu.md` (istatistik mimarisi)

---

## Notlar

- Bu task tek seferde tüm istatistik altyapısını kapsar — kapsamı daraltmak için 3 ayrı task'a bölünebilir (SQL view'lar / SQL fonksiyon / Edge Function)
- iptal filtresi `IS NOT TRUE` (boolean) veya `= false` — her ikisi de çalışır, tutarlı ol
- Eğer başka tablolarda da `iptal` kolonu varsa (örn. `stok_hareket.iptal`, `gorev_log.iptal`), bunlar ZATEN filtreli (line 1169: `AND NOT iptal`)
