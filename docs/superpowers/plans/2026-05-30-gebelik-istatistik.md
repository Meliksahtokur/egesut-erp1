# Gebelik İstatistik Kartı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Üreme sekmesinde sürü gebelik oranını ve kırılımlarını gösteren stat kart eklemek.

**Architecture:** PostgreSQL RPC (`stat_gebelik_ozet`) tüm hesaplamayı yapar, frontend sadece sonucu gösterir. Kart tab strip altında sabit durur, accordion ile detay açılır. Cache ile tekrar RPC çağrısı önlenir.

**Tech Stack:** PostgreSQL (plpgsql), Vanilla JS, Supabase JS client (`db.rpc`), IndexedDB (cache yok — direkt RPC)

**Spec:** `docs/superpowers/specs/2026-05-30-gebelik-istatistik-design.md`

---

### Task 1: Migration — `stat_gebelik_ozet` RPC

**Files:**
- Create: `supabase/migrations/20260530180000_stat_gebelik_ozet.sql`
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

- [ ] **Step 1: Create migration file**

```sql
-- supabase/migrations/20260530180000_stat_gebelik_ozet.sql

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

- [ ] **Step 2: Deploy migration**

Run: `supabase_migrate` with the SQL above.

Expected: Function created, no errors.

- [ ] **Step 3: Test RPC with real data**

Run: `supabase_rpc('stat_gebelik_ozet', '{}')`.

Expected: JSON with `ozet.toplam` > 0, `ozet.oran` as a number, `sperma_top5` array with entries.

- [ ] **Step 4: Add to ground truth**

Append the same `CREATE OR REPLACE FUNCTION` + `GRANT` block to the end of `supabase/migrations/99999999999999_ground_truth.sql`, before the final comment block (if any).

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260530180000_stat_gebelik_ozet.sql supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(stat): stat_gebelik_ozet RPC — sürü gebelik istatistikleri"
```

---

### Task 2: HTML — Stat kart container + CSS

**Files:**
- Modify: `index.html:378-401` (pg-ureme bölümü)

- [ ] **Step 1: Add stat card container and CSS**

`index.html` dosyasında `pg-ureme` bölümünü bul. `kizginlik-toolbar` div'inin kapanışından sonra, `ureme-body` div'inden önce yeni div ekle:

```html
<!-- Mevcut satır 398 civarı: </div> (kizginlik-toolbar kapanışı) -->
      <div id="ureme-stat-card"></div>
      <div id="ureme-body"><div class="loader"><div class="spin"></div></div></div>
```

CSS'i `<style>` bloğuna ekle (mevcut stillerin sonuna):

```css
.stat-card{background:var(--card);border-radius:8px;padding:10px 12px;margin-bottom:8px;cursor:pointer}
.stat-header{display:flex;justify-content:space-between;align-items:center;font-weight:600;font-size:.85rem}
.stat-summary{font-size:.8rem;color:var(--ink2);margin-top:4px}
.stat-arrow{font-size:.7rem;color:var(--ink3);transition:transform .2s}
.stat-card.open .stat-arrow{transform:rotate(180deg)}
.stat-detail{display:none;padding-top:8px;border-top:1px solid var(--border);margin-top:8px}
.stat-card.open .stat-detail{display:block}
.stat-section{margin-bottom:8px}
.stat-section:last-child{margin-bottom:0}
.stat-section-title{font-size:.75rem;font-weight:600;color:var(--ink3);margin-bottom:4px}
.stat-row{font-size:.8rem;color:var(--ink2);padding:2px 0}
```

- [ ] **Step 2: Verify HTML structure**

Open `index.html` and confirm `ureme-stat-card` div appears between `kizginlik-toolbar` and `ureme-body`.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat(stat): üreme stat kart container + CSS"
```

---

### Task 3: UI — Stat kart render + toggle

**Files:**
- Modify: `js/ui.js:1736-1749` (loadUreme fonksiyonu)

- [ ] **Step 1: Add stat render functions**

`js/ui.js` dosyasında `loadUreme` fonksiyonundan **önce** (satır ~1735 civarı) şu fonksiyonları ekle:

```javascript
// ── ÜREME STAT KARTI ────────────────────────
let _uremStatCache=null;
let _uremStatOpen=false;

async function _renderUremeStat(){
  const el=document.getElementById('ureme-stat-card'); if(!el) return;
  if(_uremStatCache){_applyStatHtml(el,_uremStatCache);return;}
  try{
    const {data}=await db.rpc('stat_gebelik_ozet',{});
    if(data){_uremStatCache=data;_applyStatHtml(el,data);}
  }catch(e){console.warn('stat_gebelik_ozet:',e.message);}
}

function _applyStatHtml(el,d){
  const o=d.ozet||{};
  const oran=o.oran!=null?`%${o.oran}`:'Veri yok';
  const katHtml=(d.kategori||[]).map(k=>{
    const ico=k.ad==='İnek'?'🐄':k.ad==='Düve'?'🐮':'❓';
    return `<div class="stat-row">${ico} ${k.ad}: ${k.toplam} tohum · ${k.gebe} gebe · <b>${k.oran!=null?'%'+k.oran:'—'}</b></div>`;
  }).join('');
  const spHtml=(d.sperma_top5||[]).map(s=>
    `<div class="stat-row">${s.ad} — ${s.toplam} tohum → <b>${s.oran!=null?'%'+s.oran:'—'}</b></div>`
  ).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const dnHtml=(d.deneme||[]).map(dn=>{
    const label=dn.no>=3?'3+':dn.no;
    return `<div class="stat-row">${label}. deneme: ${dn.gebe} gebe / ${dn.toplam} (${dn.oran!=null?'%'+dn.oran:'—'})</div>`;
  }).join('')||'<div class="stat-row" style="color:var(--ink3)">Veri yok</div>';
  el.innerHTML=`<div class="stat-card${_uremStatOpen?' open':''}" onclick="_toggleUremeStat()">
    <div class="stat-header"><span>📊 Sürü Gebelik</span><span class="stat-arrow">▼</span></div>
    <div class="stat-summary">💉 ${o.toplam||0} tohumlama · ✅ ${o.gebe||0} gebe · 📊 ${oran}</div>
    <div class="stat-detail">
      <div class="stat-section">${katHtml||'<div class="stat-row">Kategori verisi yok</div>'}</div>
      <div class="stat-section"><div class="stat-section-title">🏆 Top Spermalar (≥3 tohumlama)</div>${spHtml}</div>
      <div class="stat-section"><div class="stat-section-title">🔢 Deneme Dağılımı</div>${dnHtml}</div>
    </div>
  </div>`;
}

function _toggleUremeStat(){
  _uremStatOpen=!_uremStatOpen;
  const c=document.querySelector('#ureme-stat-card .stat-card');
  if(c) c.classList.toggle('open',_uremStatOpen);
}
```

- [ ] **Step 2: Hook into loadUreme**

`loadUreme` fonksiyonunda, `el.innerHTML='<div class="loader">...'` satırından **önce** stat render çağrısını ekle:

Mevcut `loadUreme` (~satır 1736):
```javascript
async function loadUreme(tab='kizginlik'){
  _curUremeTab=tab;
  const el=document.getElementById('ureme-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
```

Şu hale getir:
```javascript
async function loadUreme(tab='kizginlik'){
  _curUremeTab=tab;
  _renderUremeStat();
  const el=document.getElementById('ureme-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
```

`_renderUremeStat()` await edilmiyor — fire-and-forget, tab içeriğini bloklamaz.

- [ ] **Step 3: Invalidate cache on pullTables**

`js/api.js` dosyasında `pullTables` fonksiyonunu bul. Fonksiyonun başına cache invalidasyon ekle:

```javascript
async function pullTables() {
  _uremStatCache=null;
```

Bu şekilde her sync sonrası stat kartı yeniden RPC çağrısı yapar.

- [ ] **Step 4: Test manually**

1. Uygulamayı aç
2. Üreme sekmesine git
3. Stat kartının göründüğünü doğrula (💉 X tohumlama · ✅ Y gebe · 📊 %Z)
4. Karta tıkla — detay accordion açılsın
5. Tekrar tıkla — kapansın
6. Tab değiştir (Tohumlama → Gebelik) — kart kaybolmasın

- [ ] **Step 5: Commit**

```bash
git add js/ui.js js/api.js
git commit -m "feat(stat): üreme stat kartı — gebelik oranı + accordion detay"
```

---

### Task 4: Ground truth + cleanup + push

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`
- Modify: `.claude/tasks/arge/task-037-istatistik-modulu.md`

- [ ] **Step 1: Verify ground truth has the RPC**

Read `99999999999999_ground_truth.sql` and confirm `stat_gebelik_ozet` function is present (added in Task 1 Step 4). If missing, add it now.

- [ ] **Step 2: Update task status**

`.claude/tasks/arge/task-037-istatistik-modulu.md` dosyasında:
- `**Durum:** Bekliyor` → `**Durum:** ✅ TAMAMLANDI (MVP)`
- Notlara ekle: "MVP tamamlandı: stat_gebelik_ozet RPC + üreme stat kartı. Filtre UI, dedicated sekme faz 2."

- [ ] **Step 3: Commit + push**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql .claude/tasks/arge/task-037-istatistik-modulu.md
git commit -m "docs: task-037 MVP tamamlandı, ground truth güncellendi"
git push origin main
```
