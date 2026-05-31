# Üreme İstatistik Motoru — Implementation Spec

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mevcut cycle-bazlı istatistik sistemine 42-gün kuralı, kısır dışlama, sperma limit kaldırma, VWP enforcement, eligible view ve sessiz hayvanlar akışı eklemek.

**Architecture:** 3 faz, artan karmaşıklık sırasıyla. Faz A mevcut RPC/view'a filtre ekler. Faz B tohumlama_kaydet'e VWP kontrolü ekler. Faz C yeni view + dashboard listesi + otomatik görev oluşturur.

**Tech Stack:** PostgreSQL (plpgsql RPC + view), Vanilla JS (ui.js), Supabase Migration

**Referans doküman:** `docs/analysis/ureme-istatistik-mimari-durum.md`

---

## Faz A: stat_suru_ozet Düzeltmeleri

### A1. 42-Gün Kuralı

**Ne:** Son 42 gün içinde başlayan cycle'ları istatistik hesabından hariç tut — sonuçtan bağımsız olarak.

**Neden:** DairyComp 305 standardı. Sonuçlanmamış tohumlamalar güvenilir değil. Birisi yanlışlıkla Boş girerse bile 42 gün kuralı onu otomatik dışlar.

**Uygulama:**

`stat_suru_ozet` RPC'sindeki `cycles` CTE'sine filtre ekle:

```sql
-- Mevcut WHERE:
WHERE v.durum = 'Aktif'
  AND (p_padok IS NULL OR v.padok = p_padok)
  AND (NOT p_son_donem OR NOT EXISTS (...))

-- EKLENecek satır:
  AND v.baslangic < CURRENT_DATE - 42
```

**Etki:** Sadece `sonuc != 'Bekliyor'` olan cycle'ları etkiler — Bekliyor zaten paydadan çıkıyor. Bu filtre tarih bazlı ekstra güvenlik katmanı.

**Dikkat:** `hayvan_stat` CTE'si de `cycles`'dan beslendiği için hayvan bazlı istatistik de otomatik temizlenir. Ancak `devam_eden` sayısı (Bekliyor) hala gösterilmeli — kullanıcı kaç hayvanın sonuç beklediğini görmek ister. Bunun için `devam_eden` sayacını ayrı bir sorgu ile hesapla (42 gün filtresi OLMADAN, sadece `sonuc = 'Bekliyor'` olanları say).

**Devam eden ayrı sorgu:**

```sql
'devam_eden', (
  SELECT COUNT(DISTINCT v3.hayvan_id)
  FROM public.v_ureme_dongusu v3
  WHERE v3.durum = 'Aktif'
    AND (p_padok IS NULL OR v3.padok = p_padok)
    AND v3.sonuc = 'Bekliyor'
)
```

### A2. Kısır Hayvanlar Dışlama

**Ne:** `kisir = true` olan hayvanları üreme istatistiklerinden tamamen çıkar.

**Uygulama:** `v_ureme_dongusu` view'ının WHERE clause'una ekle:

```sql
-- Mevcut:
WHERE h.cinsiyet = 'Dişi'

-- Yeni:
WHERE h.cinsiyet = 'Dişi'
  AND h.kisir IS NOT TRUE
```

**Etki:** View değişince `stat_suru_ozet` otomatik temizlenir — RPC'de ek değişiklik gerekmez.

### A3. Sperma Limit Kaldırma

**Ne:** `LIMIT 5` kaldır, tüm spermaları göster. `HAVING COUNT(*) >= 3` kalır (gürültü önleme).

**Backend değişiklik:** `stat_suru_ozet` RPC'sinde `sperma_top5` bölümünden `LIMIT 5` satırını sil. JSON key adını `sperma_top5` → `sperma_all` olarak değiştir.

**Frontend değişiklik:** `_applySuruStatHtml`'de:
- `d.gebelik?.sperma_top5` → `d.gebelik?.sperma_all` (fallback: `sperma_top5` de kontrol et — geçiş dönemi)
- İlk 5'i göster, gerisi "[+N daha]" toggle ile açılır (deneme dağılımındaki pattern ile aynı)
- Section başlığı: "Top Spermalar (≥3 cycle)" → "Sperma Performansı (≥3 cycle)"

---

## Faz B: VWP Enforcement

### B1. tohumlama_kaydet RPC Değişikliği

**Ne:** Doğumdan sonra 55 gün geçmeden tohumlama engeli + override mekanizması.

**Yeni parametre:**

```sql
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id      text,
  p_tarih          date,
  p_sperma         text,
  p_hekim_id       text    DEFAULT NULL,
  p_irk_bilgisi    text    DEFAULT NULL,
  p_ek_uygulamalar jsonb   DEFAULT '[]'::jsonb,
  p_vwp_override   boolean DEFAULT false        -- YENİ
) RETURNS jsonb
```

**Kontrol mantığı (mevcut validasyonlardan SONRA, INSERT'ten ÖNCE):**

```sql
-- VWP kontrolü
DECLARE
  v_son_dogum date;
  v_vwp_gun   integer;
BEGIN
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 THEN
      IF NOT p_vwp_override THEN
        RETURN jsonb_build_object(
          'ok', false,
          'error', 'VWP_VIOLATION',
          'mesaj', format('VWP dolmadı: %s gün / 55 gün', v_vwp_gun),
          'gun', v_vwp_gun,
          'son_dogum', v_son_dogum
        );
      END IF;
      -- Override verildi — devam et ama logla
    END IF;
  END IF;
END;
```

**Override loglama (INSERT'ten SONRA):**

```sql
IF v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 AND p_vwp_override THEN
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VWP_OVERRIDE',
    p_hayvan_id,
    jsonb_build_object(
      'tohumlama_id', v_toh_id,
      'vwp_gun', p_tarih - v_son_dogum,
      'son_dogum', v_son_dogum
    )
  );
END IF;
```

**Dönüş değeri değişikliği:** Mevcut `RAISE EXCEPTION` yerine `jsonb_build_object('ok', false, ...)` kullan — frontend modal gösterebilsin. Mevcut exception'lar (`'Erkek hayvana...'`, `'Hayvan zaten gebe...'`) da aynı pattern'e çevrilmeli.

**NOT:** Mevcut RPC'de exception'lar `RAISE EXCEPTION` ile atılıyor. VWP için farklı pattern (jsonb return) kullanmak tutarsız olur. İki seçenek:

- **Seçenek 1:** VWP de exception atsın, frontend catch etsin — mevcut pattern ile tutarlı
- **Seçenek 2:** Tüm validation'ları jsonb return'e çevir — daha iyi UX ama daha fazla değişiklik

**Karar:** Seçenek 1. VWP de `RAISE EXCEPTION 'VWP_VIOLATION:...'` atsın. Frontend zaten exception mesajını gösteriyor. Mesaj formatı: `VWP_VIOLATION:45:55` (gün:limit). Frontend bunu parse edip modal gösterir.

### B2. Frontend VWP Modal

**Akış:**

1. `tohumlama_kaydet` çağrılır (override=false)
2. Exception gelir → mesaj `VWP_VIOLATION:` ile başlıyorsa:
   - Modal göster: "VWP dolmadı (X/55 gün). Yine de kaydetmek istiyor musunuz?"
   - "Evet" → `tohumlama_kaydet` tekrar çağır (override=true)
   - "Hayır" → kapat
3. Normal hata → mevcut hata gösterimi

**Badge:** Tohumlama listesinde VWP_OVERRIDE olan kayıtlar ❗ badge ile işaretlenir.

Badge verisi: `islem_log`'dan `tip = 'VWP_OVERRIDE' AND snapshot->>'tohumlama_id' = t.id` sorgusu. Alternatif: tohumlama tablosuna `vwp_override boolean DEFAULT false` kolonu ekle — daha performanslı.

**Karar:** Tohumlama tablosuna `vwp_override boolean DEFAULT false` kolonu ekle. Hem sorgu basit hem de view'dan erişilebilir.

---

## Faz C: Eligible View + Sessiz Hayvanlar

### C1. v_eligible View

**Ne:** Tohumlanabilir durumdaki hayvanları listeleyen materialized olmayan view.

```sql
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT
  h.id,
  h.kupe_no,
  h.grup,
  h.padok,
  son_dogum.tarih                    AS son_dogum_tarihi,
  CURRENT_DATE - son_dogum.tarih     AS dogum_gun,
  son_aktivite.tarih                 AS son_aktivite_tarihi,
  CURRENT_DATE - son_aktivite.tarih  AS sessiz_gun
FROM public.hayvanlar h
LEFT JOIN LATERAL (
  SELECT MAX(d.tarih) AS tarih
  FROM public.dogum d
  WHERE d.anne_id = h.id
) son_dogum ON true
LEFT JOIN LATERAL (
  SELECT MAX(tarih) AS tarih
  FROM (
    SELECT tarih FROM public.tohumlama WHERE hayvan_id = h.id
    UNION ALL
    SELECT tarih FROM public.kizginlik_log WHERE hayvan_id = h.id
  ) aktivite
) son_aktivite ON true
WHERE h.cinsiyet = 'Dişi'
  AND h.durum = 'Aktif'
  AND h.kisir IS NOT TRUE
  AND NOT EXISTS (
    SELECT 1 FROM public.tohumlama t
    WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.cases c
    WHERE c.animal_id = h.id AND c.status = 'active'
  )
  AND (
    son_dogum.tarih IS NULL                    -- düve (doğum kaydı yok)
    OR son_dogum.tarih < CURRENT_DATE - 55     -- VWP geçmiş
  );

GRANT SELECT ON public.v_eligible TO anon, authenticated;
```

**Düve handling:** `son_dogum.tarih IS NULL` → düve olarak kabul edilir. Yaş kontrolü tohumlama_kaydet'te zaten var (12 ay). View sadece "tohumlanabilir mi?" sorusunu cevaplar.

**Aktif vaka dışlama:** Tedavi altındaki hayvanlar eligible değil — sessiz hayvanlar listesine de düşmemeli.

### C2. Sessiz Hayvanlar RPC

**Ne:** 60+ gündür eligible olup hiçbir üreme aktivitesi olmayan hayvanları listele.

```sql
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok text DEFAULT NULL,
  p_min_gun integer DEFAULT 60
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'hayvan_id', e.id,
        'kupe_no', e.kupe_no,
        'grup', e.grup,
        'padok', e.padok,
        'sessiz_gun', COALESCE(e.sessiz_gun, CURRENT_DATE - e.son_dogum_tarihi),
        'son_aktivite', e.son_aktivite_tarihi
      ) ORDER BY COALESCE(e.sessiz_gun, 9999) DESC
    ), '[]'::jsonb)
    FROM public.v_eligible e
    WHERE (p_padok IS NULL OR e.padok = p_padok)
      AND COALESCE(e.sessiz_gun, CURRENT_DATE - e.son_dogum_tarihi, 9999) >= p_min_gun
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO anon, authenticated;
```

### C3. Sessiz Hayvanlar Görev Oluşturma

**Ne:** Günlük çalışan (veya stat_suru_ozet çağrıldığında tetiklenen) fonksiyon — yeni sessiz hayvanlar için VETERİNER_KONTROL görevi oluşturur.

```sql
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_gorev_olustur()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer := 0;
  v_rec   record;
BEGIN
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun
    FROM public.v_eligible e
    WHERE COALESCE(e.sessiz_gun, CURRENT_DATE - e.son_dogum_tarihi, 9999) >= 60
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.gorev_tipi = 'VETERINER_KONTROL'
          AND g.tamamlandi = false
      )
  LOOP
    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
    VALUES (
      gen_random_uuid(),
      v_rec.id,
      'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok', v_rec.sessiz_gun),
      CURRENT_DATE,
      false
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_gorev_olustur() TO anon, authenticated;
```

**Tetikleme:** `stat_suru_ozet` RPC'sinin sonunda `PERFORM sessiz_hayvanlar_gorev_olustur();` çağrısı ekle. Böylece dashboard her açıldığında kontrol yapılır — ayrı cron gerekmez.

**Duplikasyon koruması:** `NOT EXISTS (... gorev_tipi = 'VETERINER_KONTROL' AND tamamlandi = false)` — aynı hayvan için birden fazla açık görev oluşturmaz.

### C4. Dashboard UI — Sessiz Hayvanlar Kartı

**Ne:** `_applySuruStatHtml` fonksiyonuna yeni section ekle.

**Veri kaynağı:** `stat_suru_ozet` RPC'sinin dönüşüne `sessiz_hayvanlar` key'i ekle (count + ilk 5 hayvan).

**UI:**

```html
<div class="stat-section">
  <div class="stat-section-title">❗ Sessiz Hayvanlar (N)</div>
  <div class="stat-row">TR001 — 85 gün</div>
  <div class="stat-row">TR002 — 72 gün</div>
  ...
  <div class="stat-row"><span style="cursor:pointer;color:var(--blue)">Tümünü gör →</span></div>
</div>
```

**"Tümünü gör" aksiyonu:** Modal veya panel açarak `sessiz_hayvanlar_listele` RPC sonucunu gösterir. Her satırda hayvan küpe, gün sayısı, ve "Tohumla" / "Kızgınlık Kaydet" / "Vaka Aç" butonları.

---

## Migration Stratejisi

| Faz | Migration dosyası | İçerik |
|-----|-------------------|--------|
| A | `20260531_stat_42gun_kisir_sperma.sql` | v_ureme_dongusu ALTER + stat_suru_ozet v3 |
| B | `20260531_vwp_enforcement.sql` | tohumlama.vwp_override kolonu + tohumlama_kaydet v2 |
| C | `20260531_eligible_sessiz.sql` | v_eligible view + sessiz_hayvanlar RPCs + stat_suru_ozet'e sessiz ekleme |

Her migration bağımsız çalışabilir ama sıralı uygulanmalı (C, B'nin kolonuna bağlı değil ama eligible view kısır filtresini kullanır → A önce).

---

## Dokunulan Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `supabase/migrations/20260531_stat_42gun_kisir_sperma.sql` | CREATE (Faz A) |
| `supabase/migrations/20260531_vwp_enforcement.sql` | CREATE (Faz B) |
| `supabase/migrations/20260531_eligible_sessiz.sql` | CREATE (Faz C) |
| `supabase/migrations/99999999999999_ground_truth.sql` | UPDATE (canonical sync) |
| `js/ui.js` | MODIFY: sperma section + sessiz hayvanlar kartı + VWP badge |
| `js/forms.js` | MODIFY: tohumlama form — VWP error handling + override modal |

---

## Kapsam Dışı (Bu Spec'te YOK)

- 21-Day PR metriği (eligible view hazır olunca sonraki spec)
- HDR (Heat Detection Rate) hesaplaması
- Mevsimsel trend grafiği
- Demografik 1 fark araştırması
- VWP_OVERRIDE tag zinciri (gebelik/doğum kartında gösterim — gelecek iş)
- Düve yaş bazlı VWP (13-15 ay kontrolü — mevcut 12 ay kontrolü yeterli)
