# Cycle-Bazlı İstatistik Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tohumlama istatistiklerini record-bazlı sayımdan cycle-bazlı + hayvan-bazlı sentez modeline geçirmek.

**Architecture:** PostgreSQL view (`v_ureme_dongusu`) cycle detection yapar, `stat_suru_ozet` RPC bu view'dan iki seviyeli aggregation üretir (cycle→hayvan, hayvan→sürü). Frontend mevcut stat kartını yeni formata adapte eder.

**Tech Stack:** PostgreSQL (view + RPC rewrite), Vanilla JS (ui.js)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `supabase/migrations/20260530210000_v_ureme_dongusu.sql` | Create | View: cycle detection from tohumlama records |
| `supabase/migrations/20260530220000_stat_suru_ozet_v2.sql` | Create | RPC rewrite: cycle-based + animal-based sentez |
| `supabase/migrations/99999999999999_ground_truth.sql` | Modify (~8515-8661) | Canonical reference: add view + update RPC |
| `js/ui.js` | Modify (~707-770) | Stat card rendering: adapt to new JSON format |

---

### Task 1: Migration — `v_ureme_dongusu` View

**Files:**
- Create: `supabase/migrations/20260530210000_v_ureme_dongusu.sql`

- [ ] **Step 1: Create the view migration**

```sql
-- v_ureme_dongusu — her satır = 1 üreme döngüsü (cycle)
-- Cycle sınırı: deneme_no = 1 yeni cycle başlatır

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
  -- Gebe eden sperma
  MAX(CASE WHEN sonuc IN ('Gebe','Doğum Yaptı') THEN sperma_norm END) AS gebe_sperma,
  -- Son kullanılan sperma (en yüksek deneme_no'daki)
  (ARRAY_AGG(sperma_norm ORDER BY deneme_no DESC))[1] AS son_sperma
FROM numbered
GROUP BY hayvan_id, padok, durum, kategori, cycle_no;

GRANT SELECT ON public.v_ureme_dongusu TO anon, authenticated;
```

- [ ] **Step 2: Deploy migration**

Run: `supabase_migrate` with the SQL above.

Expected: View created, queryable.

- [ ] **Step 3: Verify with real data**

Run: `supabase_query` on `v_ureme_dongusu` for a known animal (bac3b8f8):

```
SELECT * FROM v_ureme_dongusu WHERE hayvan_id = 'bac3b8f8-43c3-4cf5-83ed-6e1073c16fec' ORDER BY cycle_no;
```

Expected: 2 cycles — cycle 1 (Doğum Yaptı, deneme_sayisi=2), cycle 2 (Bekliyor, deneme_sayisi=3).

- [ ] **Step 4: Verify cycle count**

Run aggregate query:
```
SELECT sonuc, COUNT(*) FROM v_ureme_dongusu WHERE durum = 'Aktif' GROUP BY sonuc;
```

Expected: Total cycles < 234 (current record count). Bekliyor cycles should be ~11.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260530210000_v_ureme_dongusu.sql
git commit -m "feat(stat): v_ureme_dongusu view — cycle detection from tohumlama"
```

---

### Task 2: Migration — `stat_suru_ozet` v2 RPC

**Files:**
- Create: `supabase/migrations/20260530220000_stat_suru_ozet_v2.sql`

- [ ] **Step 1: Write the new RPC**

```sql
-- stat_suru_ozet v2 — cycle-bazlı + hayvan-bazlı sentez
-- v_ureme_dongusu view'ından beslenır

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
  -- ── Hayvan demografisi (değişmedi) ──
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

  -- ── Cycle-bazlı gebelik istatistikleri ──
  WITH cycles AS (
    SELECT
      v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi,
      v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif'
      AND (p_padok IS NULL OR v.padok = p_padok)
      AND (
        NOT p_son_donem
        OR NOT EXISTS (
          -- Daha sonraki bir cycle'da Gebe/Doğum var mı?
          SELECT 1 FROM public.v_ureme_dongusu v2
          WHERE v2.hayvan_id = v.hayvan_id
            AND v2.cycle_no > v.cycle_no
            AND v2.sonuc IN ('Gebe','Doğum Yaptı')
        )
      )
  ),
  -- Hayvan bazlı: her hayvanın son tamamlanmış cycle sonucuna göre
  hayvan_stat AS (
    SELECT DISTINCT ON (hayvan_id)
      hayvan_id, kategori, sonuc AS son_sonuc
    FROM cycles
    ORDER BY hayvan_id, cycle_no DESC
  )
  SELECT jsonb_build_object(
    -- HAYVAN ÖZETİ
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe')
                  / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    -- CYCLE ÖZETİ
    'cycle_ozet', (
      SELECT jsonb_build_object(
        'toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
        'basarili',     COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
        'basarisiz',    COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')),
        'devam_eden',   COUNT(*) FILTER (WHERE sonuc = 'Bekliyor'),
        'oran',         ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1),
        'ort_deneme',   ROUND(
                          AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)
      ) FROM cycles
    ),
    -- KATEGORİ KIRILIMI (hayvan + cycle)
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
    -- SPERMA TOP 5 (cycle bazlı — gebe eden sperma'ya kredi)
    'sperma_top5', (
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
        LIMIT 5
      ) sub
    ),
    -- DENEME DAĞILIMI (cycle bazlı)
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
    'gebelik', COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_top5":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;
```

- [ ] **Step 2: Deploy migration**

Run: `supabase_migrate` with the SQL above.

Expected: Function replaced, same signature `(text, boolean)`.

- [ ] **Step 3: Verify Son Dönem output**

Run: `supabase_rpc('stat_suru_ozet', {p_son_donem: true})`

Expected JSON with `hayvan_ozet` and `cycle_ozet` keys. Key checks:
- `hayvan_ozet.toplam` < 73 (only animals with completed cycles)
- `cycle_ozet.toplam_cycle` < 234 (cycles, not records)
- `cycle_ozet.ort_deneme` > 1.0 (repeat breeding exists)
- No Bekliyor in toplam or toplam_cycle

- [ ] **Step 4: Verify Tüm Zamanlar output**

Run: `supabase_rpc('stat_suru_ozet', {p_son_donem: false})`

Expected: More cycles than Son Dönem. `hayvan_ozet.oran` should be higher than old record-based oran (because multiple Boş records in one cycle no longer inflate denominator).

- [ ] **Step 5: Verify padok filter**

Run: `supabase_rpc('stat_suru_ozet', {p_padok: 'Kuru/Gebe', p_son_donem: true})`

Expected: `hayvan_ozet.gebe` should not exceed `hayvan.toplam` for that padok (the bug that prompted this redesign).

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260530220000_stat_suru_ozet_v2.sql
git commit -m "feat(stat): stat_suru_ozet v2 — cycle-bazlı + hayvan-bazlı sentez"
```

---

### Task 3: Frontend — Stat Card Adaptation

**Files:**
- Modify: `js/ui.js:707-770` (`_applySuruStatHtml` function)

- [ ] **Step 1: Update `_applySuruStatHtml` to use new JSON format**

The RPC output changes from `gebelik.ozet` (record-based) to `gebelik.hayvan_ozet` + `gebelik.cycle_ozet`. Update the rendering function:

```javascript
function _applySuruStatHtml(el,d,padok){
  const h=d.hayvan||{};
  const ho=(d.gebelik||{}).hayvan_ozet||{};
  const co=(d.gebelik||{}).cycle_ozet||{};
  const oran=ho.oran!=null?`%${ho.oran}`:'—';
  const padokLabel=padok?`🏠 ${esc(padok)} — `:'';

  const demoHtml=`<div class="stat-section">
    <div class="stat-section-title">📋 Demografik</div>
    <div class="stat-row">🐄 İnek: ${h.inek||0} · 🐮 Düve: ${h.duve||0} · 🐂 Erkek: ${h.erkek||0} · 🍼 Buzağı: ${h.buzagi||0} · 💲 Kısır: ${h.kisir||0}</div>
    <div class="stat-row">🔬 Tohumlanan: ${h.tohumlanan||0}/${h.toplam||0}</div>
  </div>`;

  const katHtml=(d.gebelik?.kategori||[]).map(k=>{
    const ico=k.ad==='İnek'?'🐄':k.ad==='Düve'?'🐮':'❓';
    return `${ico} ${esc(k.ad)}: %${k.hayvan_oran!=null?k.hayvan_oran:'—'} (${k.hayvan_gebe}/${k.hayvan_toplam})`;
  }).join(' · ')||'Veri yok';

  const gebHtml=`<div class="stat-section">
    <div class="stat-section-title">🤰 Gebelik (Hayvan)</div>
    <div class="stat-row">✅ ${ho.gebe||0}/${ho.toplam||0} gebe (${oran}) · ⭕ ${ho.bos||0} boş</div>${ho.devam_eden?`<div class="stat-row" style="color:var(--ink3);font-size:.7rem">⏳ ${ho.devam_eden} hayvan sonuç bekliyor (hesaba dahil değil)</div>`:''}
    <div class="stat-row">${katHtml}</div>
  </div>`;

  const cycleHtml=`<div class="stat-section">
    <div class="stat-section-title">🔄 Cycle Özet</div>
    <div class="stat-row">${co.toplam_cycle||0} cycle · ${co.basarili||0} başarılı (%${co.oran!=null?co.oran:'—'}) · ${co.basarisiz||0} başarısız${co.devam_eden?` · ⏳ ${co.devam_eden} devam`:''}</div>
    <div class="stat-row">Ort deneme: ${co.ort_deneme!=null?co.ort_deneme:'—'}</div>
  </div>`;

  const spHtml=(d.gebelik?.sperma_top5||[]).map(s=>
    `<div class="stat-row">${esc(s.ad)} — ${s.cycle_toplam} cycle → <b>%${s.cycle_oran!=null?s.cycle_oran:'—'}</b></div>`
  ).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const spSection=`<div class="stat-section"><div class="stat-section-title">🏆 Top Spermalar (≥3 cycle)</div>${spHtml}</div>`;

  const deneme=d.gebelik?.deneme||[];
  const first3=deneme.filter(dn=>dn.no<=3);
  const rest=deneme.filter(dn=>dn.no>3);
  const dnFirst=first3.map(dn=>
    `<div class="stat-row">${dn.no} denemede gebe: ${dn.gebe}/${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const dnRest=rest.map(dn=>
    `<div class="stat-row">${dn.no} denemede gebe: ${dn.gebe}/${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const restBtn=rest.length>0?`<div id="deneme-rest" style="display:${_suruDenemeOpen?'block':'none'}">${dnRest}</div><div class="stat-row"><span onclick="_toggleDenemeRest()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">${_suruDenemeOpen?'Daralt':'[+'+rest.length+' daha]'}</span></div>`:'';
  const dnSection=`<div class="stat-section"><div class="stat-section-title">🔢 Deneme Dağılımı</div>${dnFirst}${restBtn}</div>`;

  el.innerHTML=`<div class="stat-card${_suruStatOpen?' open':''}" onclick="_toggleSuruStat(event)">
    <div class="stat-header"><span>${padokLabel}🐄 ${h.toplam||0} hayvan · 🔬 ${h.tohumlanan||0} tohumlanan · 🤰 ${ho.gebe||0} gebe (${oran})</span><span class="stat-arrow">▼</span></div>
    <div class="stat-detail"><div style="display:flex;justify-content:flex-end;margin-bottom:4px"><span onclick="_toggleStatMode(event)" style="cursor:pointer;font-size:.68rem;font-weight:600;padding:2px 8px;border-radius:4px;background:var(--ink1);color:var(--ink4)">${_suruStatMode==='son'?'Son Dönem':'Tüm Zamanlar'} ↻</span></div>${demoHtml}${gebHtml}${cycleHtml}${spSection}${dnSection}</div>
  </div>`;
}
```

Key changes from old version:
- `g` (from `gebelik.ozet`) → `ho` (from `gebelik.hayvan_ozet`) + `co` (from `gebelik.cycle_ozet`)
- Header: `gebe (oran)` now from `hayvan_ozet` instead of record-based `ozet`
- New `cycleHtml` section between gebelik and sperma sections
- Sperma: `s.toplam` → `s.cycle_toplam`, `s.oran` → `s.cycle_oran`
- Kategori: `k.toplam` → `k.hayvan_toplam`, `k.oran` → `k.hayvan_oran`
- Deneme: label changed from "N. deneme:" to "N denemede gebe:"
- Bekleyen text: "hayvan sonuç bekliyor" (was "sonuç bekliyor")

- [ ] **Step 2: Clear cache on deploy**

No code change needed — `_suruStatCache` is already cleared on page reload and in `pullTables()` (`api.js:304`).

- [ ] **Step 3: Verify in browser**

Open the app, navigate to Üreme tab. Check:
1. Stat card renders without JS errors (F12 console)
2. Header shows hayvan-bazlı gebe count/oran
3. Expand detail → Gebelik section shows hayvan_ozet
4. Cycle Özet section appears with cycle counts + ort deneme
5. Sperma shows cycle-bazlı oranlar
6. Son Dönem / Tüm Zamanlar toggle works
7. Padok filter works

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat(stat): UI cycle-bazlı sentez — hayvan + cycle özet kartı"
```

---

### Task 4: Ground Truth + Final Commit + Push

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql:8515-8661`

- [ ] **Step 1: Add view to ground truth**

Insert BEFORE the `stat_suru_ozet` function (before line 8515):

```sql
-- ── v_ureme_dongusu — cycle detection view ──
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
)
SELECT
  hayvan_id, padok, durum, kategori, cycle_no,
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

- [ ] **Step 2: Replace stat_suru_ozet in ground truth**

Replace lines 8515-8661 with the new RPC from Task 2 Step 1 (exact same SQL).

- [ ] **Step 3: Commit + push**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql .claude/ideas/alfa-istatistik.md docs/superpowers/specs/2026-05-30-cycle-bazli-istatistik-design.md docs/superpowers/plans/2026-05-30-cycle-bazli-istatistik.md
git commit -m "docs(stat): cycle-bazlı istatistik spec + plan, ground truth senkronize"
git push origin main
```
