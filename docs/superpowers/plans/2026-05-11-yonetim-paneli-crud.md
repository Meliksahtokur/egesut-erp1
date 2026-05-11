# Yonetim Paneli CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Hard FK padok management, hekim/sperma DB-backed delete with constraint checks, and dynamic grup-padok mapping to the EgeSut ayarlar panel.

**Architecture:** New `padoklar` + `grup_padok_eslem` DB tables with Hard FK from `hayvanlar.padok_id`. View updated to JOIN for display name. IDB sync extended. Hekim delete via RPC with constraint check. Config.js hardcodes replaced with DB-driven data.

**Tech Stack:** Supabase (PostgreSQL RPC + migrations), vanilla JS (no framework), IndexedDB (offline-first), existing modal/toast UI patterns.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/20260511000001_padoklar.sql` | Create | padoklar + grup_padok_eslem tables, seed, hayvanlar.padok_id FK, view update |
| `supabase/migrations/20260511000002_hekim_sperma_sil.sql` | Create | hekim_sil + sperma_sil RPC functions |
| `supabase/migrations/20260511000003_hayvan_rpc_padok_id.sql` | Create | Update hayvan_ekle + hayvan_guncelle RPCs for padok_id |
| `js/api.js` | Modify | Add padoklar, grup_padok_eslem, hekimler to FETCHERS + DB_VER bump |
| `js/config.js` | Modify | Remove GRUP_PADOK hardcode, add dynamic loader functions |
| `js/ui.js` | Modify | Padok/hekim/sperma CRUD UI in ayarlar, update padok display references |
| `js/forms.js` | Modify | Padok dropdown → DB-driven, write padok_id instead of text |
| `index.html` | Modify | Padok management section + grup esleme UI in m-ayarlar modal |

---

### Task 1: DB Migration — padoklar + grup_padok_eslem + FK

**Files:**
- Create: `supabase/migrations/20260511000001_padoklar.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- Migration: padoklar tablosu, grup_padok_eslem, hayvanlar.padok_id FK
BEGIN;

-- 1. padoklar tablosu
CREATE TABLE IF NOT EXISTS public.padoklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ad text NOT NULL UNIQUE,
  kapasite integer,
  aktif boolean DEFAULT true,
  sira integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.padoklar ENABLE ROW LEVEL SECURITY;
CREATE POLICY "padoklar_all" ON public.padoklar FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.padoklar TO anon, authenticated;

-- 2. Seed from existing padok values
INSERT INTO public.padoklar (ad, sira) VALUES
  ('Sagmal Padok', 1),
  ('Kuru/Gebe Padok', 2),
  ('Duve Padok (Buyuk)', 3),
  ('Duve Padok (Kucuk)', 4),
  ('Buzagi Padok (Sut Icenler)', 5),
  ('Buzagi Padok (Sutten Kesilmis)', 6),
  ('Besi Padok (Erkek)', 7),
  ('Besi Padok (Disi)', 8)
ON CONFLICT (ad) DO NOTHING;

-- 3. grup_padok_eslem tablosu
CREATE TABLE IF NOT EXISTS public.grup_padok_eslem (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  grup text NOT NULL,
  padok_id uuid NOT NULL REFERENCES public.padoklar(id) ON DELETE CASCADE,
  UNIQUE(grup, padok_id)
);

ALTER TABLE public.grup_padok_eslem ENABLE ROW LEVEL SECURITY;
CREATE POLICY "gpe_all" ON public.grup_padok_eslem FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.grup_padok_eslem TO anon, authenticated;

-- 4. Seed grup_padok_eslem from hardcoded GRUP_PADOK
INSERT INTO public.grup_padok_eslem (grup, padok_id)
SELECT val.grup, p.id
FROM (VALUES
  ('Sagmal (Laktasyonda)', 'Sagmal Padok'),
  ('Sagmal (Kuru)', 'Kuru/Gebe Padok'),
  ('Gebe Duve', 'Kuru/Gebe Padok'),
  ('Duve (Buyuk)', 'Duve Padok (Buyuk)'),
  ('Duve (Kucuk)', 'Duve Padok (Kucuk)'),
  ('Sut Icen Buzagi', 'Buzagi Padok (Sut Icenler)'),
  ('Sutten Kesilmis Buzagi', 'Buzagi Padok (Sutten Kesilmis)'),
  ('Besi', 'Besi Padok (Erkek)'),
  ('Besi', 'Besi Padok (Disi)')
) AS val(grup, padok_ad)
JOIN public.padoklar p ON p.ad = val.padok_ad
ON CONFLICT (grup, padok_id) DO NOTHING;

-- 5. hayvanlar.padok_id FK
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok_id uuid REFERENCES public.padoklar(id);

-- 6. Migrate existing TEXT values to padok_id
UPDATE public.hayvanlar h
SET padok_id = p.id
FROM public.padoklar p
WHERE h.padok = p.ad AND h.padok_id IS NULL;

-- 7. Update hayvan_durum_view to JOIN padoklar
CREATE OR REPLACE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id,
    h.kupe_no,
    h.devlet_kupe,
    h.irk,
    h.cinsiyet,
    h.dogum_tarihi,
    h.grup,
    h.padok_id,
    COALESCE(pk.ad, h.padok) AS padok,
    h.durum,
    h.anne_id,
    h.kategori,
    h.tohumlama_durumu,
    h.tohumlama_onay_tarihi,
    h.suttten_kesme_tarihi,
    h.cikis_tipi,
    h.cikis_tarihi,
    h.cikis_sebebi,
    h.satis_fiyati,
    h.notlar,
    h.dogum_kg,
    h.canli_agirlik,
    h.boy,
    h.renk,
    h.ayirici_ozellik,
    h.baba_bilgi,
    h.abort_sayisi,
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.padoklar pk ON pk.id = h.padok_id
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id,
    id    AS toh_id,
    tarih AS toh_tarih,
    sperma,
    sonuc AS toh_sonuc,
    (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log
  WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id,
  st.toh_tarih,
  st.sperma,
  st.toh_sonuc,
  st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi'
    WHEN y.cinsiyet = 'Disi' AND y.yas_gun BETWEEN 181 AND 365 THEN 'duve_kucuk'
    WHEN y.cinsiyet = 'Disi' AND y.yas_gun BETWEEN 366 AND 730 THEN 'duve_buyuk'
    WHEN y.cinsiyet = 'Disi' AND y.yas_gun > 730 THEN 'sagmal'
    ELSE 'genel'
  END AS hesap_kategori,
  CASE
    WHEN y.cinsiyet = 'Disi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Bos')
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true
    ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280
    ELSE 0
  END AS dogum_gecikme_gun,
  CASE
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe'
    WHEN st.toh_sonuc = 'Bekliyor' THEN 'bekliyor'
    WHEN y.yas_gun >= y.tohumlama_esik_gun AND y.cinsiyet = 'Disi' THEN 'tohumlanabilir'
    ELSE 'erken'
  END AS tohumlama_durumu_hesap
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id;

GRANT SELECT ON public.hayvan_durum_view TO anon, authenticated;

END;
```

**IMPORTANT NOTE:** The seed data uses Turkish characters WITHOUT special chars (Sagmal not Sağmal) because the current `hayvanlar.padok` field stores names with Turkish chars. The implementer MUST check the actual values in production by running:
```sql
SELECT DISTINCT padok FROM hayvanlar WHERE padok IS NOT NULL;
```
Then adjust the seed INSERT to use the EXACT same strings. If production uses `Sağmal Padok` (with ğ), the seed must use `Sağmal Padok`.

- [ ] **Step 2: Deploy migration via supabase_migrate MCP tool**

Run the SQL via `supabase_migrate` MCP tool. Verify:
```sql
SELECT * FROM padoklar ORDER BY sira;
SELECT * FROM grup_padok_eslem;
SELECT padok_id, padok, kupe_no FROM hayvan_durum_view LIMIT 5;
```

Expected: padoklar seeded with 8 rows, grup_padok_eslem with 9 rows, hayvanlar.padok_id populated, view returns both padok (name) and padok_id.

- [ ] **Step 3: Save migration file locally**

Save the migration SQL to `supabase/migrations/20260511000001_padoklar.sql`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260511000001_padoklar.sql
git commit -m "migration: padoklar + grup_padok_eslem tables, hayvanlar.padok_id FK, view update"
```

---

### Task 2: DB Migration — hekim_sil + sperma_sil RPCs

**Files:**
- Create: `supabase/migrations/20260511000002_hekim_sperma_sil.sql`

- [ ] **Step 1: Write the RPC migration**

```sql
BEGIN;

-- hekim_sil: constraint check then delete
CREATE OR REPLACE FUNCTION public.hekim_sil(p_hekim_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hekimler WHERE id = p_hekim_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hekim bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydi olan hekim silinemez');
  END IF;
  IF EXISTS (SELECT 1 FROM dogum WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Dogum kaydi olan hekim silinemez');
  END IF;
  DELETE FROM hekimler WHERE id = p_hekim_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hekim_sil(text) TO anon, authenticated;

-- sperma_sil: check tohumlama references then delete from stok
CREATE OR REPLACE FUNCTION public.sperma_sil(p_stok_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_urun_adi text;
BEGIN
  SELECT urun_adi INTO v_urun_adi FROM stok WHERE id = p_stok_id AND kategori = 'Sperma';
  IF v_urun_adi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sperma stok kaydi bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE sperma = v_urun_adi LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydinda kullanilan sperma silinemez');
  END IF;
  DELETE FROM stok_hareket WHERE stok_id = p_stok_id;
  DELETE FROM stok WHERE id = p_stok_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sperma_sil(text) TO anon, authenticated;

END;
```

- [ ] **Step 2: Deploy via supabase_migrate**

Test hekim_sil:
```sql
SELECT hekim_sil('NONEXISTENT');
-- Expected: {"ok": false, "mesaj": "Hekim bulunamadi"}
```

- [ ] **Step 3: Save file + commit**

```bash
git add supabase/migrations/20260511000002_hekim_sperma_sil.sql
git commit -m "migration: hekim_sil + sperma_sil RPCs with constraint checks"
```

---

### Task 3: DB Migration — Update hayvan RPCs for padok_id

**Files:**
- Create: `supabase/migrations/20260511000003_hayvan_rpc_padok_id.sql`

- [ ] **Step 1: Write the migration**

The existing `hayvan_ekle` RPC (in `20260306000008_blok1_backend.sql`) uses `p_padok text DEFAULT 'P1'`. It needs a new `p_padok_id uuid` parameter. The existing `hayvan_guncelle` RPC (in `20260308000010_hayvan_guncelle.sql`) uses `p_padok text`. Both need updating.

```sql
BEGIN;

-- Update hayvan_ekle: add p_padok_id parameter
-- Keep p_padok for backward compat but prefer padok_id
CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no        text    DEFAULT NULL,
  p_devlet_kupe    text    DEFAULT NULL,
  p_irk            text    DEFAULT NULL,
  p_cinsiyet       text    DEFAULT NULL,
  p_dogum_tarihi   date    DEFAULT NULL,
  p_grup           text    DEFAULT 'Genel',
  p_padok          text    DEFAULT NULL,
  p_dogum_kg       numeric DEFAULT NULL,
  p_anne_id        text    DEFAULT NULL,
  p_baba_bilgi     text    DEFAULT NULL,
  p_canli_agirlik  numeric DEFAULT NULL,
  p_boy            numeric DEFAULT NULL,
  p_renk           text    DEFAULT NULL,
  p_ayirici_ozellik text   DEFAULT NULL,
  p_padok_id       uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
  v_id := gen_random_uuid()::text;

  -- Resolve padok: prefer padok_id, fallback to text lookup
  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
    IF v_padok_id IS NULL THEN
      v_padok_ad := p_padok; -- legacy: no matching padok in DB
    END IF;
  END IF;

  INSERT INTO hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, padok_id, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, v_padok_ad, v_padok_id, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

-- Update hayvan_guncelle: add p_padok_id parameter
CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id              text,
  p_kupe_no         text    DEFAULT NULL,
  p_devlet_kupe     text    DEFAULT NULL,
  p_irk             text    DEFAULT NULL,
  p_cinsiyet        text    DEFAULT NULL,
  p_dogum_tarihi    date    DEFAULT NULL,
  p_grup            text    DEFAULT NULL,
  p_padok           text    DEFAULT NULL,
  p_dogum_kg        numeric DEFAULT NULL,
  p_canli_agirlik   numeric DEFAULT NULL,
  p_boy             numeric DEFAULT NULL,
  p_renk            text    DEFAULT NULL,
  p_ayirici_ozellik text    DEFAULT NULL,
  p_baba_bilgi      text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL,
  p_anne_id         text    DEFAULT NULL,
  p_padok_id        uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
  -- Resolve padok
  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
  END IF;

  UPDATE hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),        kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),    devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),            irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),       cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,              dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),           grup),
    padok            = COALESCE(v_padok_ad,                  padok),
    padok_id         = COALESCE(v_padok_id,                  padok_id),
    dogum_kg         = COALESCE(p_dogum_kg,                  dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,             canli_agirlik),
    boy              = COALESCE(p_boy,                       boy),
    renk             = COALESCE(NULLIF(p_renk,''),           renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''),ayirici_ozellik),
    baba_bilgi       = COALESCE(NULLIF(p_baba_bilgi,''),     baba_bilgi),
    notlar           = COALESCE(NULLIF(p_notlar,''),         notlar),
    anne_id          = COALESCE(NULLIF(p_anne_id,''),         anne_id)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_ekle(text,text,text,text,date,text,text,numeric,text,text,numeric,numeric,text,text,uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hayvan_guncelle(text,text,text,text,text,date,text,text,numeric,numeric,numeric,text,text,text,text,text,uuid) TO anon, authenticated;

END;
```

**IMPORTANT:** The GRANT statements need exact parameter type lists matching the function signature. If the deploy fails on GRANT, remove them — existing grants may already cover these functions.

- [ ] **Step 2: Deploy via supabase_migrate + verify**

```sql
SELECT padok_id, padok FROM hayvan_durum_view WHERE padok IS NOT NULL LIMIT 3;
```

- [ ] **Step 3: Save file + commit**

```bash
git add supabase/migrations/20260511000003_hayvan_rpc_padok_id.sql
git commit -m "migration: hayvan_ekle + hayvan_guncelle RPCs now accept padok_id"
```

---

### Task 4: IDB Sync — Add new tables, bump DB version

**Files:**
- Modify: `js/api.js` (lines ~42 for DB_VER, ~65 for onupgradeneeded, ~260 for FETCHERS)

- [ ] **Step 1: Bump DB_VER from 14 to 15**

In `js/api.js`, find `const DB_VER = 14` and change to `const DB_VER = 15`.

- [ ] **Step 2: Add object stores in onupgradeneeded**

In `js/api.js`, find the `onupgradeneeded` callback. It creates object stores. Add after the existing stores:

```javascript
if (!db.objectStoreNames.contains('padoklar'))
  db.createObjectStore('padoklar', { keyPath: 'id' });
if (!db.objectStoreNames.contains('grup_padok_eslem'))
  db.createObjectStore('grup_padok_eslem', { keyPath: 'id' });
if (!db.objectStoreNames.contains('hekimler'))
  db.createObjectStore('hekimler', { keyPath: 'id' });
```

- [ ] **Step 3: Add FETCHERS for new tables**

In `js/api.js`, inside the `FETCHERS` object in `pullTables()` (around line 260), add:

```javascript
padoklar:         () => db.from('padoklar').select('*').eq('aktif', true).order('sira'),
grup_padok_eslem: () => db.from('grup_padok_eslem').select('*'),
hekimler:         () => db.from('hekimler').select('*').eq('aktif', true),
```

- [ ] **Step 4: Add new tables to RPC_TABLES or initial sync**

Find where `pullTables` is called with the initial table list (likely in an init function). Add `'padoklar', 'grup_padok_eslem', 'hekimler'` to that list.

- [ ] **Step 5: Commit**

```bash
git add js/api.js
git commit -m "feat: IDB sync for padoklar, grup_padok_eslem, hekimler (DB_VER 15)"
```

---

### Task 5: Config.js — Replace hardcodes with DB-driven loaders

**Files:**
- Modify: `js/config.js` (lines 7-12 for HEKIMLER, 46-56 for GRUP_PADOK)

- [ ] **Step 1: Replace GRUP_PADOK with dynamic loader**

Replace lines 46-56 in `js/config.js`:

```javascript
// BEFORE:
// const GRUP_PADOK = { ... hardcoded ... };

// AFTER:
let GRUP_PADOK = {};

async function loadPadokConfig() {
  const padoklar = await getData('padoklar');
  const eslem = await getData('grup_padok_eslem');
  const padokMap = {};
  padoklar.forEach(p => { padokMap[p.id] = p.ad; });
  GRUP_PADOK = {};
  eslem.forEach(e => {
    if (!GRUP_PADOK[e.grup]) GRUP_PADOK[e.grup] = [];
    const ad = padokMap[e.padok_id];
    if (ad && !GRUP_PADOK[e.grup].includes(ad)) GRUP_PADOK[e.grup].push(ad);
  });
}
```

- [ ] **Step 2: Keep HEKIMLER as fallback, add loader**

```javascript
// BEFORE (line 7-12):
// let HEKIMLER = [ ... hardcoded ... ];
// const VARSAYILAN_HEKIM = 'H1';

// AFTER:
let HEKIMLER = [
  { id: 'H1', ad: 'Melik Tokur' },
  { id: 'H2', ad: 'Hüseyin Aygün' },
  { id: 'H3', ad: 'Süleyman Kocabaş' },
];
const VARSAYILAN_HEKIM = 'H1';

async function loadHekimlerFromDB() {
  const dbHekimler = await getData('hekimler');
  if (dbHekimler.length > 0) HEKIMLER = dbHekimler;
}
```

- [ ] **Step 3: Call loaders after IDB sync**

In the app init flow (likely `js/app.js` or wherever `pullTables` completes), call:

```javascript
await loadPadokConfig();
await loadHekimlerFromDB();
```

Find the exact location — search for `pullTables(` calls and add after them.

- [ ] **Step 4: Commit**

```bash
git add js/config.js
git commit -m "feat: GRUP_PADOK + HEKIMLER now load from DB, hardcode is fallback"
```

---

### Task 6: Index.html — Padok management section in ayarlar

**Files:**
- Modify: `index.html` (inside `m-ayarlar` modal, around line 1069-1124)

- [ ] **Step 1: Add padok management section**

Find the `m-ayarlar` modal content. Add a new section BEFORE the hekimler section:

```html
<!-- Padok Yonetimi -->
<div style="margin-bottom:20px">
  <div style="font-weight:600;font-size:.95rem;margin-bottom:8px;color:var(--ink)">Padoklar</div>
  <div id="ay-padok-list"></div>
  <div id="ay-padok-form" style="display:none;margin-top:8px;padding:10px;background:var(--card2);border-radius:10px">
    <input id="ay-padok-ad" placeholder="Padok adi" style="width:100%;padding:8px;border:1px solid var(--brd);border-radius:8px;margin-bottom:6px">
    <input id="ay-padok-kap" type="number" placeholder="Kapasite (opsiyonel)" style="width:100%;padding:8px;border:1px solid var(--brd);border-radius:8px;margin-bottom:6px">
    <div style="display:flex;gap:6px">
      <button class="btn btn-g" onclick="ayarlarPadokKaydet()" style="flex:1">Kaydet</button>
      <button class="btn btn-o" onclick="g('ay-padok-form').style.display='none'" style="flex:1">Iptal</button>
    </div>
  </div>
  <button onclick="g('ay-padok-form').style.display='block'" style="margin-top:6px;background:none;border:1px dashed var(--brd);border-radius:8px;padding:8px;width:100%;color:var(--green);cursor:pointer;font-size:.8rem">+ Yeni Padok</button>
</div>

<!-- Grup-Padok Esleme -->
<div style="margin-bottom:20px">
  <div style="font-weight:600;font-size:.95rem;margin-bottom:8px;color:var(--ink)">Grup → Padok Esleme</div>
  <div id="ay-grup-eslem-list"></div>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: padok management + grup esleme sections in ayarlar modal"
```

---

### Task 7: UI.js — Padok CRUD functions

**Files:**
- Modify: `js/ui.js` (add new functions near the existing ayarlar functions ~line 3398)

- [ ] **Step 1: Add padok list renderer**

Add after the existing `renderAyarlarSpermaList` function:

```javascript
async function renderAyarlarPadokList(){
  const el=g('ay-padok-list'); if(!el) return;
  const padoklar=await getData('padoklar');
  const hayvanlar=await getData('hayvanlar');
  padoklar.sort((a,b)=>(a.sira||0)-(b.sira||0));
  el.innerHTML=padoklar.map(p=>{
    const count=hayvanlar.filter(h=>h.padok_id===p.id).length;
    return `<div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--card2)">
      <div>
        <span style="font-size:.85rem;color:var(--ink)">${p.ad}</span>
        <span style="font-size:.65rem;color:var(--ink3);margin-left:6px">${count} hayvan${p.kapasite?' / '+p.kapasite:''}</span>
      </div>
      <div style="display:flex;gap:8px;align-items:center">
        <button onclick="padokYenidenAdlandir('${p.id}','${p.ad.replace(/'/g,"\\'")}')" style="background:none;border:none;color:var(--blue);font-size:.7rem;cursor:pointer">Duzenle</button>
        <button onclick="padokSil('${p.id}',${count})" style="background:none;border:none;color:var(--red);font-size:.7rem;cursor:pointer">Sil</button>
      </div>
    </div>`;
  }).join('');
}
```

- [ ] **Step 2: Add padok CRUD operations**

```javascript
async function ayarlarPadokKaydet(){
  const ad=v('ay-padok-ad').trim(); if(!ad) return;
  const kap=parseInt(v('ay-padok-kap'))||null;
  const id=crypto.randomUUID();
  const{error}=await db.from('padoklar').insert({id,ad,kapasite:kap,aktif:true,sira:99});
  if(error){toast('Hata: '+error.message);return;}
  await pullTables(['padoklar']);
  cl('ay-padok-ad');cl('ay-padok-kap');
  g('ay-padok-form').style.display='none';
  await renderAyarlarPadokList();
  await loadPadokConfig();
  toast('Padok eklendi: '+ad);
}

async function padokYenidenAdlandir(id,eskiAd){
  const yeniAd=prompt('Yeni padok adi:',eskiAd);
  if(!yeniAd||yeniAd===eskiAd) return;
  const{error}=await db.from('padoklar').update({ad:yeniAd}).eq('id',id);
  if(error){toast('Hata: '+error.message);return;}
  await pullTables(['padoklar','hayvanlar']);
  await renderAyarlarPadokList();
  await loadPadokConfig();
  toast('Padok yeniden adlandirildi');
}

async function padokSil(id,count){
  if(count>0){toast('Icinde '+count+' hayvan var. Once hayvanlari tasiyin.');return;}
  openConfirm('Padok Sil','Bu padogu silmek istediginizden emin misiniz?',async()=>{
    const{error}=await db.from('padoklar').delete().eq('id',id);
    if(error){toast('Hata: '+error.message);return;}
    await pullTables(['padoklar','grup_padok_eslem']);
    await renderAyarlarPadokList();
    await renderGrupPadokEslem();
    await loadPadokConfig();
    toast('Padok silindi');
  });
}
```

- [ ] **Step 3: Add grup-padok esleme renderer**

```javascript
async function renderGrupPadokEslem(){
  const el=g('ay-grup-eslem-list'); if(!el) return;
  const padoklar=await getData('padoklar');
  const eslem=await getData('grup_padok_eslem');
  const gruplar=['Sagmal (Laktasyonda)','Sagmal (Kuru)','Gebe Duve','Duve (Buyuk)','Duve (Kucuk)','Sut Icen Buzagi','Sutten Kesilmis Buzagi','Besi'];
  const padokMap={};
  padoklar.forEach(p=>{padokMap[p.id]=p.ad;});

  el.innerHTML=gruplar.map(grup=>{
    const mevcut=eslem.filter(e=>e.grup===grup).map(e=>padokMap[e.padok_id]).filter(Boolean);
    const opts=padoklar.map(p=>`<option value="${p.id}"${mevcut.includes(p.ad)?' selected':''}>${p.ad}</option>`).join('');
    return `<div style="display:flex;align-items:center;gap:8px;padding:6px 0;border-bottom:1px solid var(--card2)">
      <span style="font-size:.75rem;color:var(--ink);min-width:130px">${grup}</span>
      <select onchange="grupPadokDegistir('${grup}',this.value)" style="flex:1;padding:6px;border:1px solid var(--brd);border-radius:6px;font-size:.75rem">
        <option value="">-- Sec --</option>
        ${opts}
      </select>
      <span style="font-size:.65rem;color:var(--ink3)">${mevcut.join(', ')||'Atanmamis'}</span>
    </div>`;
  }).join('');
}

async function grupPadokDegistir(grup, padokId){
  if(!padokId) return;
  await db.from('grup_padok_eslem').delete().eq('grup',grup);
  await db.from('grup_padok_eslem').insert({id:crypto.randomUUID(),grup,padok_id:padokId});
  await pullTables(['grup_padok_eslem']);
  await renderGrupPadokEslem();
  await loadPadokConfig();
  toast('Esleme guncellendi');
}
```

**NOTE:** The grup names MUST match the exact strings used in the database. The implementer should verify with `SELECT DISTINCT grup FROM hayvanlar` and adjust. Turkish chars (ğ, ü, ı, ş, ç, ö) must be exact.

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat: padok CRUD + grup-padok esleme management in ayarlar"
```

---

### Task 8: UI.js — Hekim + Sperma DB-backed delete

**Files:**
- Modify: `js/ui.js` (update existing customHekimSil ~line 3437, customSpermaSil ~line 3453)

- [ ] **Step 1: Update hekim list to show all hekimler from DB**

Replace `renderAyarlarHekimList()` (line 3398-3405):

```javascript
async function renderAyarlarHekimList(){
  const el=g('ay-hekim-list'); if(!el) return;
  const all=await getData('hekimler');
  el.innerHTML=all.map(h=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.85rem;color:var(--ink)">${h.ad}${h.id===VARSAYILAN_HEKIM?' <span style="font-size:.6rem;color:var(--green)">(varsayilan)</span>':''}</span>
    <button onclick="hekimSil('${h.id}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>
  </div>`).join('');
}
```

- [ ] **Step 2: Replace customHekimSil with DB-backed hekimSil**

Replace `customHekimSil` function:

```javascript
async function hekimSil(id){
  openConfirm('Hekim Sil','Bu hekimi silmek istediginizden emin misiniz?',async()=>{
    const res=await rpc('hekim_sil',{p_hekim_id:id});
    if(!res.ok){toast(res.mesaj||'Hata');return;}
    await pullTables(['hekimler']);
    await loadHekimlerFromDB();
    await renderAyarlarHekimList();
    // Update select dropdowns
    ['b-hekim','i-hekim','d-hekim','ta-hekim'].forEach(sid=>{
      const el=g(sid); if(!el) return;
      const opt=el.querySelector(`option[value="${id}"]`);
      if(opt) opt.remove();
    });
    toast('Hekim silindi');
  });
}
```

- [ ] **Step 3: Update ayarlarHekimKaydet to write to DB**

Replace `ayarlarHekimKaydet` (line 3427-3436):

```javascript
async function ayarlarHekimKaydet(){
  const ad=v('ay-hek-ad').trim(); if(!ad) return;
  const id='H'+Date.now();
  const{error}=await db.from('hekimler').insert({id,ad,aktif:true});
  if(error){toast('Hata: '+error.message);return;}
  await pullTables(['hekimler']);
  await loadHekimlerFromDB();
  ['b-hekim','i-hekim','d-hekim','ta-hekim'].forEach(sid=>{
    const el=g(sid); if(!el) return;
    el.innerHTML+=`<option value="${id}">${ad}</option>`;
  });
  cl('ay-hek-ad');
  g('ay-hekim-form').style.display='none';
  await renderAyarlarHekimList();
  toast(ad+' eklendi');
}
```

- [ ] **Step 4: Update sperma delete to use DB**

Replace `customSpermaSil`:

```javascript
async function spermaSil(stokId){
  openConfirm('Sperma Sil','Bu spermayi silmek istediginizden emin misiniz?',async()=>{
    const res=await rpc('sperma_sil',{p_stok_id:stokId});
    if(!res.ok){toast(res.mesaj||'Hata');return;}
    await pullTables(['stok']);
    buildSpermaList();
    renderAyarlarSpermaList();
    toast('Sperma silindi');
  });
}
```

Update `renderAyarlarSpermaList` to show stok-based sperma with stok_id:

```javascript
async function renderAyarlarSpermaList(){
  const el=g('ay-sperma-list'); if(!el) return;
  const stoklar=await getData('stok');
  const spermaStok=stoklar.filter(s=>s.kategori==='Sperma');
  el.innerHTML=spermaStok.map(s=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.8rem;color:var(--ink)">${s.urun_adi} <span style="font-size:.65rem;color:var(--ink3)">(${s.guncel||0} ${s.birim||'adet'})</span></span>
    <button onclick="spermaSil('${s.id}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>
  </div>`).join('');
}
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat: hekim + sperma DB-backed CRUD with constraint checks"
```

---

### Task 9: Forms.js — Padok dropdown from DB

**Files:**
- Modify: `js/forms.js` (padok select population, padok_id write)

- [ ] **Step 1: Update padok dropdown population**

Find where `a-padok` select is populated (search for `a-padok` in forms.js or ui.js). Replace hardcoded GRUP_PADOK options with DB-driven:

```javascript
async function populatePadokSelect(selectId, selectedId){
  const sel=g(selectId); if(!sel) return;
  const padoklar=await getData('padoklar');
  sel.innerHTML='<option value="">-- Padok Sec --</option>'+
    padoklar.map(p=>`<option value="${p.id}"${p.id===selectedId?' selected':''}>${p.ad}</option>`).join('');
}
```

Call this when opening animal forms (hayvan ekleme + duzenleme).

- [ ] **Step 2: Update form submission to send padok_id**

In `forms.js` line ~61 and ~85, change:
```javascript
// BEFORE:
p_padok: v('a-padok') || null
// AFTER:
p_padok_id: v('a-padok') || null
```

Since `a-padok` select now has UUID values (padok IDs), the form sends padok_id directly.

- [ ] **Step 3: Update bulk vaccine/drug padok filters**

In `forms.js` lines ~1104 and ~1217, the padok filtering uses `a.padok` (string from view). This still works because the view returns `padok` as a string name via JOIN. No change needed here.

- [ ] **Step 4: Commit**

```bash
git add js/forms.js
git commit -m "feat: padok selects now DB-driven, forms send padok_id"
```

---

### Task 10: Call renderers on ayarlar open + init loaders

**Files:**
- Modify: `js/ui.js` (wherever m-ayarlar is opened)
- Modify: `js/app.js` or init function

- [ ] **Step 1: Call padok + grup renderers when ayarlar opens**

Find where `openM('m-ayarlar')` is called or where the ayarlar panel renders its content. Add:

```javascript
renderAyarlarPadokList();
renderGrupPadokEslem();
```

alongside the existing `renderAyarlarHekimList()` and `renderAyarlarSpermaList()` calls.

- [ ] **Step 2: Call config loaders after initial sync**

Find the app init flow (after `pullTables` with initial tables). Add:

```javascript
await loadPadokConfig();
await loadHekimlerFromDB();
```

This ensures GRUP_PADOK and HEKIMLER are populated from DB after first sync.

- [ ] **Step 3: Test end-to-end**

Open the app → Ayarlar:
1. Padoklar section visible with 8 seeded padoks
2. Grup esleme section visible with group→padok mappings
3. Add a new padok → appears in list
4. Rename a padok → updated everywhere
5. Delete empty padok → removed
6. Delete padok with animals → error message
7. Delete hekim with no records → success
8. Delete hekim with tohumlama → error message

- [ ] **Step 4: Commit**

```bash
git add js/ui.js js/app.js
git commit -m "feat: ayarlar panel wired up — padok, grup esleme, hekim, sperma all functional"
```
