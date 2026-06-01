# Üreme İstatistik Motoru — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mevcut cycle-bazlı istatistik sistemine 42-gün kuralı, kısır dışlama, sperma limit kaldırma, VWP enforcement, eligible view ve sessiz hayvanlar akışı eklemek.

**Architecture:** 3 faz sıralı migration + UI değişiklikleri. Faz A mevcut view/RPC'ye filtre ekler. Faz B tohumlama_kaydet'e VWP kontrolü ekler. Faz C yeni v_eligible view + sessiz hayvanlar RPC'si + dashboard kartı oluşturur.

**Tech Stack:** PostgreSQL 15 (plpgsql), Vanilla JS, Supabase Management API (migration)

**Spec:** `docs/superpowers/specs/2026-05-31-ureme-istatistik-motoru-design.md`

---

## File Structure

| Dosya | Rol |
|-------|-----|
| `supabase/migrations/20260531100000_faz_a_42gun_kisir_sperma.sql` | CREATE: view rebuild + RPC v3 |
| `supabase/migrations/20260531200000_faz_b_vwp_enforcement.sql` | CREATE: tohumlama.vwp_override kolonu + RPC güncelleme |
| `supabase/migrations/20260531300000_faz_c_eligible_sessiz.sql` | CREATE: v_eligible view + sessiz RPC'ler + stat_suru_ozet sessiz ekleme |
| `supabase/migrations/99999999999999_ground_truth.sql` | MODIFY: canonical sync (3 faz sonunda) |
| `js/ui.js:707-757` | MODIFY: sperma section expand + sessiz hayvanlar kartı |
| `js/forms.js:240-270` | MODIFY: VWP error handling + override modal |

---

### Task 1: Faz A — v_ureme_dongusu'na kısır filtresi ekle

**Files:**
- Create: `supabase/migrations/20260531100000_faz_a_42gun_kisir_sperma.sql`

- [x] **Step 1: Migration dosyası oluştur — view rebuild**

```sql
-- Faz A: 42-gün kuralı + kısır dışlama + sperma limit kaldırma

-- ═══ 1. v_ureme_dongusu — kısır filtresi ═══
CREATE OR REPLACE VIEW public.v_ureme_dongusu AS
WITH numbered AS (
  SELECT
    t.id,
    t.hayvan_id,
    t.tarih,
    t.sonuc,
    t.deneme_no,
    LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
    SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no
            ROWS UNBOUNDED PRECEDING) AS cycle_no,
    CASE
      WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
      WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
      WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
           OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
           OR h.grup ILIKE '%kuru%' THEN 'İnek'
      ELSE 'Bilinmiyor'
    END AS kategori,
    h.padok,
    h.durum
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  WHERE h.cinsiyet = 'Dişi'
    AND h.kisir IS NOT TRUE
)
SELECT
  hayvan_id,
  padok,
  durum,
  kategori,
  cycle_no,
  MIN(tarih)           AS baslangic,
  MAX(tarih)           AS bitis,
  MAX(deneme_no)       AS deneme_sayisi,
  CASE
    WHEN bool_or(sonuc IN ('Gebe','Doğum Yaptı')) THEN 'Gebe'
    WHEN bool_or(sonuc = 'Abort')                 THEN 'Abort'
    WHEN bool_or(sonuc = 'Bekliyor')              THEN 'Bekliyor'
    ELSE 'Boş'
  END                  AS sonuc,
  MAX(CASE WHEN sonuc IN ('Gebe','Doğum Yaptı') THEN sperma_norm END) AS gebe_sperma,
  (ARRAY_AGG(sperma_norm ORDER BY deneme_no DESC))[1] AS son_sperma
FROM numbered
GROUP BY hayvan_id, padok, durum, kategori, cycle_no;

GRANT SELECT ON public.v_ureme_dongusu TO anon, authenticated;
```

- [x] **Step 2: Aynı dosyaya stat_suru_ozet v3 ekle — 42-gün kuralı + sperma limit kaldırma**

Aynı migration dosyasına append et:

```sql
-- ═══ 2. stat_suru_ozet v3 — 42-gün kuralı + sperma_all ═══
DROP FUNCTION IF EXISTS public.stat_suru_ozet(text, boolean);

CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok     text    DEFAULT NULL,
  p_son_donem boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   jsonb;
  v_gebelik  jsonb;
BEGIN
  -- ── Hayvan demografisi ──
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE
                grup ILIKE '%inek%' OR grup LIKE '%İnek%'
                OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%'
                OR grup ILIKE '%kuru%'
                OR EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'duve',   COUNT(*) FILTER (WHERE
                (grup ILIKE '%düve%' OR grup ILIKE '%duve%')
                AND NOT EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'buzagi', COUNT(*) FILTER (WHERE grup ILIKE '%buzağı%' OR grup ILIKE '%buzagi%'),
    'erkek',  COUNT(*) FILTER (WHERE cinsiyet = 'Erkek'),
    'kisir',  COUNT(*) FILTER (WHERE kisir = true),
    'hasta',  (SELECT COUNT(DISTINCT c.animal_id)
               FROM public.cases c
               JOIN public.hayvanlar h2 ON h2.id = c.animal_id
               WHERE c.status = 'active'
                 AND h2.durum = 'Aktif'
                 AND (p_padok IS NULL OR h2.padok = p_padok)),
    'tohumlanan', (SELECT COUNT(DISTINCT t2.hayvan_id)
                   FROM public.tohumlama t2
                   JOIN public.hayvanlar h3 ON h3.id = t2.hayvan_id
                   WHERE h3.durum = 'Aktif'
                     AND h3.cinsiyet = 'Dişi'
                     AND (p_padok IS NULL OR h3.padok = p_padok))
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif'
    AND (p_padok IS NULL OR h.padok = p_padok);

  -- ── Cycle-bazlı gebelik istatistikleri (42-gün kuralı uygulanmış) ──
  WITH cycles AS (
    SELECT
      v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi,
      v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif'
      AND (p_padok IS NULL OR v.padok = p_padok)
      AND v.baslangic < CURRENT_DATE - 42
      AND (
        NOT p_son_donem
        OR NOT EXISTS (
          SELECT 1 FROM public.v_ureme_dongusu v2
          WHERE v2.hayvan_id = v.hayvan_id
            AND v2.cycle_no > v.cycle_no
            AND v2.sonuc IN ('Gebe','Doğum Yaptı')
        )
      )
  ),
  hayvan_stat AS (
    SELECT DISTINCT ON (hayvan_id)
      hayvan_id, kategori, sonuc AS son_sonuc
    FROM cycles
    ORDER BY hayvan_id, cycle_no DESC
  )
  SELECT jsonb_build_object(
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', (SELECT COUNT(DISTINCT v3.hayvan_id)
                     FROM public.v_ureme_dongusu v3
                     WHERE v3.durum = 'Aktif'
                       AND (p_padok IS NULL OR v3.padok = p_padok)
                       AND v3.sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe')
                  / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    'cycle_ozet', (
      SELECT jsonb_build_object(
        'toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
        'basarili',     COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
        'basarisiz',    COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')),
        'devam_eden',   (SELECT COUNT(*)
                         FROM public.v_ureme_dongusu v4
                         WHERE v4.durum = 'Aktif'
                           AND (p_padok IS NULL OR v4.padok = p_padok)
                           AND v4.sonuc = 'Bekliyor'),
        'oran',         ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1),
        'ort_deneme',   ROUND(
                          AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)
      ) FROM cycles
    ),
    'kategori', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', hs.kategori,
          'hayvan_toplam', COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'),
          'hayvan_gebe',   COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe'),
          'hayvan_oran',   ROUND(
                             100.0 * COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe')
                             / NULLIF(COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 0), 1),
          'cycle_toplam',  (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'),
          'cycle_basarili',(SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe'),
          'cycle_oran',    ROUND(
                             100.0 * (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe')
                             / NULLIF((SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM hayvan_stat hs
        GROUP BY hs.kategori
      ) sub
    ),
    'sperma_all', (
      SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', COALESCE(gebe_sperma, son_sperma),
          'cycle_toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'cycle_basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
          'cycle_oran', ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM cycles
        WHERE sonuc != 'Bekliyor'
        GROUP BY COALESCE(gebe_sperma, son_sperma)
        HAVING COUNT(*) >= 3
        ORDER BY ROUND(
                   100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                   / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC
      ) sub
    ),
    'deneme', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'no', deneme_sayisi,
          'gebe',   COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM cycles
        WHERE sonuc != 'Bekliyor'
        GROUP BY deneme_sayisi
      ) sub
    )
  ) INTO v_gebelik
  FROM hayvan_stat;

  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0}'::jsonb),
    'gebelik', COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;
```

- [x] **Step 3: Migration'ı uygula**

Run: `supabase_migrate` with the full SQL from steps 1-2 concatenated.

Expected: Migration applied successfully.

- [x] **Step 4: Doğrula — RPC çağrısı**

Run: `supabase_rpc({function_name: "stat_suru_ozet", params: "{}"})`

Expected: JSON response with `sperma_all` key (not `sperma_top5`), `devam_eden` counts present, 42-gün öncesi cycle'lar dahil.

- [x] **Step 5: UI güncelle — sperma section expand pattern**

Modify `js/ui.js:737-740`. Replace:

```javascript
  const spHtml=(d.gebelik?.sperma_top5||[]).map(s=>
    `<div class="stat-row">${esc(s.ad)} — ${s.cycle_toplam} cycle → <b>%${s.cycle_oran!=null?s.cycle_oran:'—'}</b></div>`
  ).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const spSection=`<div class="stat-section"><div class="stat-section-title">🏆 Top Spermalar (≥3 cycle)</div>${spHtml}</div>`;
```

With:

```javascript
  const spAll=d.gebelik?.sperma_all||d.gebelik?.sperma_top5||[];
  const spFirst=spAll.slice(0,5);
  const spRest=spAll.slice(5);
  const spFirstHtml=spFirst.map(s=>
    `<div class="stat-row">${esc(s.ad)} — ${s.cycle_toplam} cycle → <b>%${s.cycle_oran!=null?s.cycle_oran:'—'}</b></div>`
  ).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const spRestHtml=spRest.map(s=>
    `<div class="stat-row">${esc(s.ad)} — ${s.cycle_toplam} cycle → <b>%${s.cycle_oran!=null?s.cycle_oran:'—'}</b></div>`
  ).join('');
  const spRestBtn=spRest.length>0?`<div id="sperma-rest" style="display:${_suruSpermaOpen?'block':'none'}">${spRestHtml}</div><div class="stat-row"><span onclick="_toggleSpermaRest()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">${_suruSpermaOpen?'Daralt':'[+'+spRest.length+' daha]'}</span></div>`:'';
  const spSection=`<div class="stat-section"><div class="stat-section-title">🏆 Sperma Performansı (≥3 cycle)</div>${spFirstHtml}${spRestBtn}</div>`;
```

- [x] **Step 6: Sperma toggle state + handler ekle**

Find `let _suruDenemeOpen=false;` in ui.js (around line 760-770) and add after it:

```javascript
let _suruSpermaOpen=false;
function _toggleSpermaRest(){
  _suruSpermaOpen=!_suruSpermaOpen;
  const el=document.getElementById('sperma-rest');
  if(el)el.style.display=_suruSpermaOpen?'block':'none';
  const parent=el?.parentElement;
  if(parent){const btn=parent.querySelector('[onclick*="toggleSpermaRest"]');if(btn)btn.textContent=_suruSpermaOpen?'Daralt':'[+'+(document.querySelectorAll('#sperma-rest .stat-row').length)+' daha]';}
}
```

- [x] **Step 7: Commit Faz A**

```bash
git add supabase/migrations/20260531100000_faz_a_42gun_kisir_sperma.sql js/ui.js
git commit -m "feat(stat): Faz A — 42-gün kuralı + kısır dışlama + sperma limit kaldırma"
```

---

### Task 2: Faz B — VWP Enforcement

**Files:**
- Create: `supabase/migrations/20260531200000_faz_b_vwp_enforcement.sql`
- Modify: `js/forms.js:240-270`

- [x] **Step 1: Migration oluştur — kolon + RPC güncelleme**

```sql
-- Faz B: VWP Enforcement — tohumlama.vwp_override kolonu + tohumlama_kaydet güncelleme

-- ═══ 1. Kolon ekle ═══
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS vwp_override boolean DEFAULT false;

-- ═══ 2. tohumlama_kaydet güncelle ═══
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id      text,
  p_tarih          date,
  p_sperma         text,
  p_hekim_id       text    DEFAULT NULL,
  p_irk_bilgisi    text    DEFAULT NULL,
  p_ek_uygulamalar jsonb   DEFAULT '[]'::jsonb,
  p_vwp_override   boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
  v_ek       jsonb;
  v_ek_stok  uuid;
  v_son_dogum date;
  v_vwp_gun  integer;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  -- Erkek kontrolü
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  -- Yaş kontrolü (12 ay = 365 gün)
  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  -- Aktif gebelik kontrolü
  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  -- İleri tarih kontrolü
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  -- VWP kontrolü (55 gün)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  -- Deneme no
  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

  -- Tohumlama kaydı
  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme, p_ek_uygulamalar,
     CASE WHEN v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 THEN true ELSE false END);

  -- VWP override loglama
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

  -- Kontrol görevleri
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  -- Ek uygulama stok düşüm
  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
      IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
        v_ek_stok := (v_ek->>'stok_id')::uuid;
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
        VALUES (
          v_ek_stok,
          'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh_id,
    'deneme_no',    v_deneme
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) TO anon, authenticated;
```

- [x] **Step 2: Migration'ı uygula**

Run: `supabase_migrate` with the full SQL from step 1.

Expected: Migration applied successfully.

- [x] **Step 3: Doğrula — VWP exception test**

Doğum kaydı olan bir hayvan bul ve 55 gün içinde tohumlama dene:

Run: `supabase_rpc({function_name: "tohumlama_kaydet", params: "{\"p_hayvan_id\":\"TEST_ID\",\"p_tarih\":\"2026-05-31\",\"p_sperma\":\"Test\"}"})`

Expected: Exception with `VWP_VIOLATION:X:55` message (or normal success if no recent birth).

- [x] **Step 4: Frontend — VWP error handling + override modal**

Modify `js/forms.js:240-270`. Replace the try block:

```javascript
  try {
    const result = await rpc('tohumlama_kaydet', {
      p_hayvan_id:      hayvan.id,
      p_tarih:          tarih,
      p_sperma:         sperma,
      p_hekim_id:       v('i-hekim') || null,
      p_ek_uygulamalar: JSON.stringify(_ekUygulamalar),
    });
```

With:

```javascript
  try {
    const result = await rpc('tohumlama_kaydet', {
      p_hayvan_id:      hayvan.id,
      p_tarih:          tarih,
      p_sperma:         sperma,
      p_hekim_id:       v('i-hekim') || null,
      p_ek_uygulamalar: JSON.stringify(_ekUygulamalar),
      p_vwp_override:   globalThis._vwpOverride || false,
    });
    globalThis._vwpOverride = false;
```

- [x] **Step 5: Frontend — VWP exception catch**

In the same function, find the `catch` block (around line 275-280) and add VWP handling BEFORE the generic error handler. Find:

```javascript
  } catch (e) {
```

And replace the catch block with:

```javascript
  } catch (e) {
    const msg = e?.message || e?.toString() || '';
    const vwpMatch = msg.match(/VWP_VIOLATION:(\d+):(\d+)/);
    if (vwpMatch) {
      const gun = vwpMatch[1];
      const limit = vwpMatch[2];
      if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; }
      const ok = confirm(`❗ VWP dolmadı: ${gun}/${limit} gün.\n\nDoğumdan sonra yeterli süre geçmemiş.\nYine de kaydetmek istiyor musunuz?`);
      if (ok) {
        globalThis._vwpOverride = true;
        return submitTohumlama();
      }
      return;
    }
```

- [x] **Step 6: Commit Faz B**

```bash
git add supabase/migrations/20260531200000_faz_b_vwp_enforcement.sql js/forms.js
git commit -m "feat(stat): Faz B — VWP enforcement (55 gün) + override modal"
```

---

### Task 3: Faz C — Eligible View + Sessiz Hayvanlar

**Files:**
- Create: `supabase/migrations/20260531300000_faz_c_eligible_sessiz.sql`
- Modify: `js/ui.js:707-757`

- [x] **Step 1: Migration oluştur — v_eligible view**

```sql
-- Faz C: Eligible view + Sessiz hayvanlar RPC'leri

-- ═══ 1. v_eligible view ═══
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT
  h.id,
  h.kupe_no,
  h.grup,
  h.padok,
  son_dogum.tarih                    AS son_dogum_tarihi,
  CURRENT_DATE - son_dogum.tarih     AS dogum_gun,
  son_aktivite.tarih                 AS son_aktivite_tarihi,
  CASE
    WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
    WHEN son_dogum.tarih IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
    ELSE NULL
  END                                AS sessiz_gun
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
    son_dogum.tarih IS NULL
    OR son_dogum.tarih < CURRENT_DATE - 55
  );

GRANT SELECT ON public.v_eligible TO anon, authenticated;
```

- [x] **Step 2: Aynı dosyaya sessiz hayvanlar RPC'leri ekle**

```sql
-- ═══ 2. sessiz_hayvanlar_listele ═══
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok   text    DEFAULT NULL,
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
        'sessiz_gun', COALESCE(e.sessiz_gun, 9999),
        'son_aktivite', e.son_aktivite_tarihi
      ) ORDER BY COALESCE(e.sessiz_gun, 9999) DESC
    ), '[]'::jsonb)
    FROM public.v_eligible e
    WHERE (p_padok IS NULL OR e.padok = p_padok)
      AND COALESCE(e.sessiz_gun, 9999) >= p_min_gun
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO anon, authenticated;

-- ═══ 3. sessiz_hayvanlar_gorev_olustur ═══
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
    WHERE COALESCE(e.sessiz_gun, 9999) >= 60
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
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', COALESCE(v_rec.sessiz_gun, 0), v_rec.kupe_no),
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

- [x] **Step 3: stat_suru_ozet'e sessiz hayvanlar ekleme**

Aynı migration dosyasına append et. `stat_suru_ozet`'in RETURN satırını güncelle — `sessiz_hayvanlar_gorev_olustur()` çağrısı + dönüşe sessiz sayısı ekle:

```sql
-- ═══ 4. stat_suru_ozet'e sessiz tetikleme ekle ═══
-- NOT: stat_suru_ozet v3 zaten Faz A'da yeniden yazıldı.
-- Burada sadece fonksiyon sonuna sessiz görev tetikleme ekliyoruz.

CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok     text    DEFAULT NULL,
  p_son_donem boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   jsonb;
  v_gebelik  jsonb;
  v_sessiz   integer;
BEGIN
  -- Sessiz hayvanlar görev oluştur (side effect)
  SELECT sessiz_hayvanlar_gorev_olustur() INTO v_sessiz;

  -- ── Hayvan demografisi ──
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE
                grup ILIKE '%inek%' OR grup LIKE '%İnek%'
                OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%'
                OR grup ILIKE '%kuru%'
                OR EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'duve',   COUNT(*) FILTER (WHERE
                (grup ILIKE '%düve%' OR grup ILIKE '%duve%')
                AND NOT EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'buzagi', COUNT(*) FILTER (WHERE grup ILIKE '%buzağı%' OR grup ILIKE '%buzagi%'),
    'erkek',  COUNT(*) FILTER (WHERE cinsiyet = 'Erkek'),
    'kisir',  COUNT(*) FILTER (WHERE kisir = true),
    'hasta',  (SELECT COUNT(DISTINCT c.animal_id)
               FROM public.cases c
               JOIN public.hayvanlar h2 ON h2.id = c.animal_id
               WHERE c.status = 'active'
                 AND h2.durum = 'Aktif'
                 AND (p_padok IS NULL OR h2.padok = p_padok)),
    'tohumlanan', (SELECT COUNT(DISTINCT t2.hayvan_id)
                   FROM public.tohumlama t2
                   JOIN public.hayvanlar h3 ON h3.id = t2.hayvan_id
                   WHERE h3.durum = 'Aktif'
                     AND h3.cinsiyet = 'Dişi'
                     AND (p_padok IS NULL OR h3.padok = p_padok)),
    'sessiz', (SELECT COUNT(*) FROM public.v_eligible e
               WHERE (p_padok IS NULL OR e.padok = p_padok)
                 AND COALESCE(e.sessiz_gun, 9999) >= 60)
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif'
    AND (p_padok IS NULL OR h.padok = p_padok);

  -- ── Cycle-bazlı gebelik istatistikleri (42-gün kuralı) ──
  WITH cycles AS (
    SELECT
      v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi,
      v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif'
      AND (p_padok IS NULL OR v.padok = p_padok)
      AND v.baslangic < CURRENT_DATE - 42
      AND (
        NOT p_son_donem
        OR NOT EXISTS (
          SELECT 1 FROM public.v_ureme_dongusu v2
          WHERE v2.hayvan_id = v.hayvan_id
            AND v2.cycle_no > v.cycle_no
            AND v2.sonuc IN ('Gebe','Doğum Yaptı')
        )
      )
  ),
  hayvan_stat AS (
    SELECT DISTINCT ON (hayvan_id)
      hayvan_id, kategori, sonuc AS son_sonuc
    FROM cycles
    ORDER BY hayvan_id, cycle_no DESC
  )
  SELECT jsonb_build_object(
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', (SELECT COUNT(DISTINCT v3.hayvan_id)
                     FROM public.v_ureme_dongusu v3
                     WHERE v3.durum = 'Aktif'
                       AND (p_padok IS NULL OR v3.padok = p_padok)
                       AND v3.sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe')
                  / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    'cycle_ozet', (
      SELECT jsonb_build_object(
        'toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
        'basarili',     COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
        'basarisiz',    COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')),
        'devam_eden',   (SELECT COUNT(*)
                         FROM public.v_ureme_dongusu v4
                         WHERE v4.durum = 'Aktif'
                           AND (p_padok IS NULL OR v4.padok = p_padok)
                           AND v4.sonuc = 'Bekliyor'),
        'oran',         ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1),
        'ort_deneme',   ROUND(
                          AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)
      ) FROM cycles
    ),
    'kategori', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', hs.kategori,
          'hayvan_toplam', COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'),
          'hayvan_gebe',   COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe'),
          'hayvan_oran',   ROUND(
                             100.0 * COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe')
                             / NULLIF(COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 0), 1),
          'cycle_toplam',  (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'),
          'cycle_basarili',(SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe'),
          'cycle_oran',    ROUND(
                             100.0 * (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe')
                             / NULLIF((SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM hayvan_stat hs
        GROUP BY hs.kategori
      ) sub
    ),
    'sperma_all', (
      SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', COALESCE(gebe_sperma, son_sperma),
          'cycle_toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'cycle_basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
          'cycle_oran', ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM cycles
        WHERE sonuc != 'Bekliyor'
        GROUP BY COALESCE(gebe_sperma, son_sperma)
        HAVING COUNT(*) >= 3
        ORDER BY ROUND(
                   100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                   / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC
      ) sub
    ),
    'deneme', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'no', deneme_sayisi,
          'gebe',   COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM cycles
        WHERE sonuc != 'Bekliyor'
        GROUP BY deneme_sayisi
      ) sub
    )
  ) INTO v_gebelik
  FROM hayvan_stat;

  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0,"sessiz":0}'::jsonb),
    'gebelik', COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;
```

- [x] **Step 4: Migration'ı uygula**

Run: `supabase_migrate` with full SQL from steps 1-3 concatenated.

Expected: Migration applied successfully.

- [x] **Step 5: Doğrula — v_eligible view**

Run: `supabase_query({table: "v_eligible", select: "*", limit: 5})`

Expected: Eligible hayvanlar listesi — dişi, aktif, gebe değil, kısır değil, VWP geçmiş.

- [x] **Step 6: Doğrula — sessiz_hayvanlar_listele**

Run: `supabase_rpc({function_name: "sessiz_hayvanlar_listele", params: "{}"})`

Expected: JSON array with sessiz_gun >= 60 olan hayvanlar (veya boş array).

- [x] **Step 7: UI — Sessiz hayvanlar kartı ekle**

Modify `js/ui.js`. Find the line with `${dnSection}</div>` (around line 756) inside `_applySuruStatHtml`. Before `${dnSection}`, add the sessiz section:

After `const dnSection=...` (line 752), add:

```javascript
  const sessizCount=h.sessiz||0;
  const sessizSection=sessizCount>0?`<div class="stat-section"><div class="stat-section-title">❗ Sessiz Hayvanlar (${sessizCount})</div><div class="stat-row" style="color:var(--ink3);font-size:.7rem">60+ gündür tohumlama/kızgınlık kaydı yok</div><div class="stat-row"><span onclick="_showSessizList()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">Listeyi gör →</span></div></div>`:'';
```

Then update the `el.innerHTML` line to include `${sessizSection}` before `${dnSection}`:

Replace:
```javascript
${spSection}${dnSection}</div>
```
With:
```javascript
${spSection}${sessizSection}${dnSection}</div>
```

- [x] **Step 8: UI — Sessiz hayvanlar liste modal**

Add after `_toggleSpermaRest` function:

```javascript
async function _showSessizList(){
  try{
    const list=await rpc('sessiz_hayvanlar_listele',{});
    if(!list||!list.length){toast('Sessiz hayvan yok');return;}
    const rows=list.map(s=>`<tr><td>${esc(s.kupe_no||'?')}</td><td>${s.sessiz_gun>=9999?'—':s.sessiz_gun+' gün'}</td><td>${s.son_aktivite||'—'}</td></tr>`).join('');
    const html=`<div style="padding:12px"><h3 style="margin:0 0 8px">❗ Sessiz Hayvanlar</h3><table class="mini-tbl"><thead><tr><th>Küpe</th><th>Sessiz</th><th>Son Aktivite</th></tr></thead><tbody>${rows}</tbody></table></div>`;
    openBottomSheet(html);
  }catch(e){toast('Hata: '+e.message);}
}
```

- [x] **Step 9: Commit Faz C**

```bash
git add supabase/migrations/20260531300000_faz_c_eligible_sessiz.sql js/ui.js
git commit -m "feat(stat): Faz C — v_eligible view + sessiz hayvanlar listesi + görev oluşturma"
```

---

### Task 4: Ground Truth Sync + Push

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

- [x] **Step 1: ground_truth.sql'i güncelle**

Ground truth dosyasında aşağıdaki bölümleri güncelle:

1. `v_ureme_dongusu` view tanımı (line ~8516-8558) → Faz A versiyonuyla değiştir (kısır filtresi ekli)
2. `stat_suru_ozet` fonksiyonu (line ~8560-8719) → Faz C final versiyonuyla değiştir (42-gün + sperma_all + sessiz)
3. `tohumlama_kaydet` fonksiyonu (line ~1472-1577) → Faz B versiyonuyla değiştir (VWP parametresi + kontrol)
4. `tohumlama` tablo tanımına `vwp_override boolean DEFAULT false` ekle
5. `v_eligible` view tanımı ekle (yeni bölüm)
6. `sessiz_hayvanlar_listele` + `sessiz_hayvanlar_gorev_olustur` fonksiyonları ekle (yeni bölüm)

- [x] **Step 2: Commit + Push**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "docs(db): ground_truth sync — Faz A/B/C (42-gün, VWP, eligible, sessiz)"
git push origin main
```
