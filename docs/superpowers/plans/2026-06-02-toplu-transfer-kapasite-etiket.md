# Toplu Transfer + Kapasite + Besi Etiket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sürü dashboardına toplu padok transfer, kapasite uyarı sistemi ve besi etiket akışı ekle.

**Architecture:** 3 katman — (1) DB: `etiketler` kolonu + RPC revizyon, (2) UI: doluluk widget + seçim modu + action bar, (3) Modal: `m-bulk-transfer` tab-based modal + besi etiket akışı. Tüm validasyon önce backend'de (RPC), sonra frontend'de (grup uyum, kapasite gösterimi). All-or-nothing transaction.

**Tech Stack:** PostgreSQL (Supabase RPC), Vanilla JS, HTML/CSS. Canonical referans: `supabase/migrations/99999999999999_ground_truth.sql`. Spec: `docs/superpowers/specs/2026-06-02-toplu-transfer-kapasite-etiket.md`.

---

## Dosya Haritası

| Dosya | Değişiklik |
|-------|-----------|
| `supabase/migrations/20260602000001_etiketler_kolonu.sql` | **YENİ** — etiketler text[] kolonu + GIN index |
| `supabase/migrations/20260602000002_padok_rpc_kapasite.sql` | **YENİ** — padok_degistir kapasite + padok_degistir_toplu all-or-nothing |
| `supabase/migrations/99999999999999_ground_truth.sql` | **GÜNCELLE** — her iki RPC'nin yeni versiyonunu yansıt |
| `index.html` | **GÜNCELLE** — doluluk bar HTML (~satır 355), action bar HTML (~satır 386), m-bulk-transfer modal (~satır 1797) |
| `js/ui.js` | **GÜNCELLE** — state vars (~5452), doluluk bar render, seçim modu fonksiyonları, modal fonksiyonları |
| `js/utils/handlers.js` | **GÜNCELLE** — yeni bt-* handler kayıtları (~satır 243) |

---

## Task 1: etiketler Kolonu Migration

**Files:**
- Create: `supabase/migrations/20260602000001_etiketler_kolonu.sql`

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- supabase/migrations/20260602000001_etiketler_kolonu.sql
ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS etiketler text[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_hayvanlar_etiketler
  ON hayvanlar USING GIN(etiketler);

COMMENT ON COLUMN hayvanlar.etiketler IS
  'Hayvan etiketleri. Geçerli değerler: kisir, satista';
```

- [ ] **Step 2: Supabase'e uygula**

```bash
cd /root/egesut-erp1
npx supabase db push
```

Beklenen: `Applied 1 migration` çıktısı, hata yok.

- [ ] **Step 3: ground_truth.sql güncelle**

`supabase/migrations/99999999999999_ground_truth.sql` içinde `hayvanlar` tablosunun CREATE TABLE bloğunu bul, `etiketler text[] DEFAULT '{}'` kolonunu ekle. Aynı dosyada GIN index'i de ekle.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260602000001_etiketler_kolonu.sql
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(db): hayvanlar.etiketler text[] kolonu + GIN index"
```

---

## Task 2: `padok_degistir` RPC — Kapasite Kontrolü

**Files:**
- Create: `supabase/migrations/20260602000002_padok_rpc_kapasite.sql`
- Modify: `supabase/migrations/99999999999999_ground_truth.sql` (satır ~7040-7110)

- [ ] **Step 1: Yeni migration dosyasını oluştur**

```sql
-- supabase/migrations/20260602000002_padok_rpc_kapasite.sql

CREATE OR REPLACE FUNCTION padok_degistir(
  p_hayvan_id text,
  p_yeni_padok_id uuid,
  p_not text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan        hayvanlar%ROWTYPE;
  v_yeni_padok    padoklar%ROWTYPE;
  v_aktif_sayisi  integer;
  v_doluluk_yuzde integer;
  v_kapasite_uyari boolean := false;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan FROM hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı');
  END IF;

  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Zaten aynı padokta mı?
  IF v_hayvan.padok_id = p_yeni_padok_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta');
  END IF;

  -- Kapasite kontrolü
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi >= v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   v_aktif_sayisi::text || '/' || v_yeni_padok.kapasite::text
      );
    END IF;

    v_doluluk_yuzde  := ROUND((v_aktif_sayisi::numeric / v_yeni_padok.kapasite) * 100);
    v_kapasite_uyari := v_doluluk_yuzde >= 80;
  END IF;

  -- Güncelle
  UPDATE hayvanlar
     SET padok_id   = p_yeni_padok_id,
         padok      = v_yeni_padok.ad,
         updated_at = now()
   WHERE id = p_hayvan_id;

  -- İşlem logu (kolon isimleri ground_truth.sql:295-313'e göre)
  INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
  VALUES ('padok_degisim', p_hayvan_id, p_hayvan_id, '{}'::jsonb,
          COALESCE(p_not, 'Padok değiştirildi → ' || v_yeni_padok.ad));

  RETURN jsonb_build_object(
    'success',         true,
    'yeni_padok',      v_yeni_padok.ad,
    'yeni_padok_id',   p_yeni_padok_id,
    'kapasite_uyari',  v_kapasite_uyari
  );
END;
$$;

GRANT EXECUTE ON FUNCTION padok_degistir(text, uuid, text) TO anon, authenticated;
```

- [ ] **Step 2: padok_degistir_toplu — all-or-nothing versiyonu aynı dosyaya ekle**

```sql
CREATE OR REPLACE FUNCTION padok_degistir_toplu(
  p_hayvan_ids   text[],
  p_yeni_padok_id uuid,
  p_etiketler    text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
BEGIN
  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Kapasite hard block (validasyon, yazma yok)
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  -- Hayvan validasyonları (validasyon, yazma yok)
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;
  END LOOP;

  -- Tüm validasyonlar geçti — yazma işlemleri
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad);
  END LOOP;

  -- Etiket güncelleme (varsa, mevcut etiketlerle birleştir)
  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION padok_degistir_toplu(text[], uuid, text[]) TO anon, authenticated;
```

- [ ] **Step 3: Supabase'e uygula**

```bash
npx supabase db push
```

Beklenen: `Applied 1 migration` (veya 2 — her iki migration), hata yok.

- [ ] **Step 4: ground_truth.sql güncelle**

`99999999999999_ground_truth.sql` içinde:
- Satır ~7040-7110: `padok_degistir` fonksiyonunu yeni versiyonuyla değiştir
- Satır ~7114-7200: `padok_degistir_toplu` fonksiyonunu yeni versiyonuyla değiştir (imza değişti: `p_etiketler text[] DEFAULT NULL` eklendi)

- [ ] **Step 5: Manuel test — kapasite dolu senaryosu**

Supabase Dashboard > SQL Editor:
```sql
-- Test: dolu padoğa transfer
SELECT padok_degistir('TEST_HAYVAN_ID', 'DOLU_PADOK_UUID', null);
-- Beklenen: { "success": false, "error": "kapasite_dolu", "detay": "20/20" }

-- Test: başarılı toplu transfer
SELECT padok_degistir_toplu(ARRAY['H1','H2'], 'HEDEF_PADOK_UUID', null);
-- Beklenen: { "success": true, "hayvan_sayisi": 2, ... }

-- Test: etiket ile transfer
SELECT padok_degistir_toplu(ARRAY['H1'], 'BESI_PADOK_UUID', ARRAY['kisir']);
-- Beklenen: { "success": true, ... }, hayvanlar.etiketler = '{kisir}'
```

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260602000002_padok_rpc_kapasite.sql
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(rpc): padok_degistir kapasite kontrolü + padok_degistir_toplu all-or-nothing + etiket desteği"
```

---

## Task 3: index.html — Padok Doluluk Bar HTML

**Files:**
- Modify: `index.html` (~satır 355, 386, 1797)

- [ ] **Step 1: Padok doluluk bar'ı ekle**

`index.html` içinde arama çubuğu div'i (`<div class="search-bar">`) ile filter chips div'i arasına ekle:

```html
<!-- Padok Doluluk Bar -->
<div id="padok-doluluk-bar" style="overflow-x:auto;white-space:nowrap;padding:4px 0 8px;display:flex;gap:6px;-webkit-overflow-scrolling:touch"></div>
```

- [ ] **Step 2: Bottom action bar HTML'ini ekle**

Sürü listesi div'inin (`<div id="suru-body">` veya `id="suru-list"`) hemen öncesine ekle:

```html
<!-- Toplu Transfer Action Bar -->
<div id="bt-action-bar" style="display:none;position:sticky;bottom:0;background:var(--card);border-top:2px solid var(--blue);padding:10px 12px;margin:0 -16px;z-index:20;animation:slideup .2s ease;box-shadow:0 -4px 20px rgba(0,0,0,.3)">
  <div style="display:flex;align-items:center;gap:10px">
    <span id="bt-count" style="font-weight:800;font-size:.85rem;color:var(--blue)">0 hayvan seçildi</span>
    <span id="bt-padok-count" style="font-size:.72rem;color:var(--ink3)"></span>
    <div style="flex:1"></div>
    <button class="btn btn-sm btn-b" id="bt-transfer-btn" data-action="bt-transfer" disabled>🔀 Taşı</button>
    <button class="btn btn-sm btn-o" data-action="bt-cancel" style="margin:0">İptal</button>
  </div>
</div>
```

- [ ] **Step 3: m-bulk-transfer modal HTML'ini ekle**

`m-padok-transfer` modal'ının kapanış div'inden (`</div>`) hemen sonrasına ekle (~satır 1797):

```html
<!-- m-bulk-transfer: Toplu Padok Transfer Modal -->
<div id="m-bulk-transfer" class="mo" onclick="if(event.target===this)closeM('m-bulk-transfer')">
  <div class="mo-box" onclick="event.stopPropagation()">
    <div class="mo-handle"></div>
    <div class="mo-title">
      🔀 Toplu Padok Değişimi
      <button class="mo-close" data-action="close-bulk-transfer">×</button>
    </div>
    <div class="mo-body">

      <!-- Tab butonları — bulkTabSwitch('bt', tab) forms.js:1547 bekler: id=bt-tab-* class=btn btn-g/btn-o -->
      <div style="display:flex;gap:4px;margin-bottom:12px;overflow-x:auto">
        <button class="btn btn-g" id="bt-tab-padok" data-action="bt-tab-padok">📋 Padok</button>
        <button class="btn btn-o" id="bt-tab-filtre" data-action="bt-tab-filtre">🎯 Filtre</button>
        <button class="btn btn-o" id="bt-tab-serbest" data-action="bt-tab-serbest">✋ Serbest</button>
      </div>

      <!-- Tab: Padok — bulkTabSwitch bekler: id=bt-section-padok -->
      <div id="bt-section-padok">
        <div class="fg">
          <label class="flbl">Kaynak Padok</label>
          <select class="fsel" id="bt-kaynak-padok-sel" onchange="btKaynakPadokSec(this.value)">
            <option value="">— Padok Seç —</option>
          </select>
        </div>
        <button class="btn btn-g" onclick="btGetKaynakHayvanlar()" style="width:100%;margin-bottom:10px">🔍 Hayvanları Getir</button>
      </div>

      <!-- Tab: Filtre — bulkTabSwitch bekler: id=bt-section-filtre style="display:none" -->
      <div id="bt-section-filtre" style="display:none">
        <div class="fg">
          <label class="flbl">Grup</label>
          <select class="fsel" id="bt-f-grup">
            <option value="">Tüm Gruplar</option>
          </select>
        </div>
        <div style="display:flex;gap:8px;margin-bottom:10px">
          <div style="flex:1">
            <label class="flbl">Cinsiyet</label>
            <select class="fsel" id="bt-f-cinsiyet">
              <option value="">Tümü</option>
              <option>Dişi</option>
              <option>Erkek</option>
            </select>
          </div>
          <div style="flex:1">
            <label class="flbl">Yaş (ay)</label>
            <div style="display:flex;gap:4px;align-items:center">
              <input type="number" id="bt-f-yas-min" placeholder="min" class="fi" style="padding:8px 10px;font-size:.8rem">
              <span style="color:var(--ink3);font-size:.75rem">–</span>
              <input type="number" id="bt-f-yas-max" placeholder="max" class="fi" style="padding:8px 10px;font-size:.8rem">
            </div>
          </div>
        </div>
        <button class="btn btn-b" onclick="btApplyFiltre()" style="width:100%">🎯 Filtrele</button>
      </div>

      <!-- Tab: Serbest — bulkTabSwitch bekler: id=bt-section-serbest style="display:none" -->
      <div id="bt-section-serbest" style="display:none">
        <input class="fi" id="bt-serbest-ara" placeholder="🔍 Küpe ara…" style="margin-bottom:6px" oninput="btSerbestAra(this.value)">
        <div id="bt-serbest-liste" style="max-height:150px;overflow-y:auto;border:1px solid var(--card3);border-radius:var(--r1);padding:6px;margin-bottom:6px"></div>
      </div>

      <!-- Seçili hayvanlar -->
      <div style="border-top:1px solid var(--card2);padding-top:10px;margin-top:8px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
          <span class="flbl" style="text-transform:none;letter-spacing:0">Seçili Hayvanlar</span>
          <span id="bt-secili-sayac" style="font-size:.72rem;font-weight:700;color:var(--blue)">0 hayvan</span>
        </div>
        <div id="bt-secili-liste" style="max-height:140px;overflow-y:auto;border:1px solid var(--card2);border-radius:var(--r1);padding:4px 8px;min-height:36px"></div>
      </div>

      <!-- Hedef padok -->
      <div style="border-top:1px solid var(--card2);padding-top:10px;margin-top:8px">
        <label class="flbl">Hedef Padok</label>
        <div id="bt-hedef-liste" style="display:flex;flex-direction:column;gap:5px;margin-top:6px"></div>
      </div>

      <!-- Özet -->
      <div id="bt-ozet" style="display:none;background:var(--card2);border-radius:var(--r1);padding:10px 12px;margin-top:8px;font-size:.75rem">
        <div style="display:flex;justify-content:space-between;padding:2px 0"><span style="color:var(--ink3)">📦 Transfer</span><span id="bt-ozet-transfer" style="font-weight:600"></span></div>
        <div style="display:flex;justify-content:space-between;padding:2px 0"><span style="color:var(--ink3)">📊 Kapasite</span><span id="bt-ozet-kap" style="font-weight:600"></span></div>
        <div style="display:flex;justify-content:space-between;padding:2px 0"><span style="color:var(--ink3)">✅ Grup Uyumu</span><span id="bt-ozet-grup" style="font-weight:600"></span></div>
      </div>

      <!-- Besi etiket bölümü (gizli, besi padok seçilince açılır) -->
      <div id="bt-etiket-bolum" style="display:none;border:1px solid var(--amber);border-radius:var(--r1);padding:10px 12px;margin-top:8px;background:rgba(232,144,12,.06)">
        <div style="font-size:.78rem;font-weight:700;color:var(--amber);margin-bottom:8px">⚠️ Besi Padoğuna Transfer — Etiket Zorunlu</div>
        <!-- Toplu ata -->
        <div style="margin-bottom:8px">
          <label style="font-size:.68rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;display:block;margin-bottom:4px">Toplu Ata</label>
          <label style="display:inline-flex;align-items:center;gap:6px;margin-right:12px;font-size:.82rem;cursor:pointer">
            <input type="checkbox" id="bt-et-toplu-kisir" onchange="btEtiketTopluDegisti()" style="accent-color:var(--blue)"> Kısır
          </label>
          <label style="display:inline-flex;align-items:center;gap:6px;font-size:.82rem;cursor:pointer">
            <input type="checkbox" id="bt-et-toplu-satista" onchange="btEtiketTopluDegisti()" style="accent-color:var(--blue)"> Satışta
          </label>
        </div>
        <!-- Tek tek -->
        <div>
          <label style="font-size:.68rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;display:block;margin-bottom:4px">— veya Tek Tek —</label>
          <div id="bt-etiket-tektek-liste" style="max-height:120px;overflow-y:auto"></div>
        </div>
      </div>

      <!-- Aksiyonlar -->
      <button id="bt-onay-btn" class="btn btn-g" onclick="btTransferOnayla()" style="width:100%;margin-top:12px;padding:12px" disabled>
        🔀 Hayvanları Taşı
      </button>
      <button class="btn btn-o" data-action="close-bulk-transfer" style="width:100%;margin-top:6px">İptal</button>

    </div>
  </div>
</div>
```

- [ ] **Step 4: Toolbar'a Toplu Taşı butonunu ekle**

`index.html` içinde sürü sayfası toolbar'ında arama inputu ve padok filtresi dropdown'ının yanına (`search-bar` div içinde) ekle:

```html
<button id="bt-toggle-btn" class="btn btn-sm" 
        style="background:rgba(42,107,181,.12);color:var(--blue);border:1px solid rgba(42,107,181,.2);white-space:nowrap"
        data-action="bt-toggle-mode">🔀 Toplu Taşı</button>
```

- [ ] **Step 5: Seçim modu banner'ını ekle**

Padok doluluk bar'ın altına, filter chips'in üstüne:

```html
<div id="bt-banner" style="display:none;background:rgba(42,107,181,.1);border:1px solid rgba(42,107,181,.25);border-radius:var(--r1);padding:8px 12px;font-size:.75rem;color:var(--blue);margin-bottom:8px;align-items:center;gap:8px">
  <span>🔀</span>
  <span>Seçim modu: hayvanlara tıklayarak seçin</span>
</div>
```

- [ ] **Step 6: CSS ekle (index.html `<style>` içine)**

```css
/* Padok doluluk chip */
.pdoluluk-chip{display:inline-flex;align-items:center;gap:6px;background:var(--card);border:1.5px solid var(--card3);border-radius:20px;padding:4px 10px;cursor:pointer;flex-shrink:0;transition:border-color .12s}
.pdoluluk-chip:hover{border-color:var(--ink3)}
.pdoluluk-ad{font-size:.68rem;font-weight:700;color:var(--ink2);white-space:nowrap;max-width:80px;overflow:hidden;text-overflow:ellipsis}
.pdoluluk-bar-wrap{width:36px;height:4px;background:var(--card3);border-radius:2px;overflow:hidden}
.pdoluluk-fill{height:100%;border-radius:2px;transition:width .3s}
.pdoluluk-sayi{font-size:.62rem;font-weight:700;white-space:nowrap}

/* Seçim modu — hayvan kartı */
.animal-card.bt-selected{border-color:var(--blue)!important;background:rgba(42,107,181,.07)!important}
.bt-cb{width:18px;height:18px;cursor:pointer;flex-shrink:0;accent-color:var(--blue);opacity:0;transition:opacity .15s;pointer-events:none}
.bt-mode .bt-cb{opacity:1;pointer-events:auto}

/* Hedef padok seçim listesi */
.bt-padok-opt{display:flex;align-items:center;gap:8px;padding:8px 10px;border-radius:var(--r1);border:1.5px solid var(--card2);cursor:pointer;transition:all .1s;margin-bottom:4px}
.bt-padok-opt:hover:not(.disabled){border-color:var(--card3)}
.bt-padok-opt.selected{border-color:var(--blue);background:rgba(42,107,181,.07)}
.bt-padok-opt.disabled{opacity:.35;pointer-events:none}
.bt-padok-opt .bpo-ad{flex:1;font-weight:600;font-size:.82rem}
.bt-padok-opt .bpo-bar-wrap{width:60px;height:4px;background:var(--card2);border-radius:2px;overflow:hidden}
.bt-padok-opt .bpo-bar-fill{height:100%;border-radius:2px}

/* Tab paneller — .tab-panel/.tab-btn KULLANILMIYOR
   bulkTabSwitch('bt',tab) forms.js:1547 inline style + btn btn-g/btn-o class kullanır
   id: bt-section-padok/filtre/serbest, butonlar: bt-tab-padok/filtre/serbest */

/* Seçili hayvan satırı (modal içi) */
.bt-hayvan-satir{display:flex;align-items:center;gap:6px;padding:5px 2px;border-bottom:1px solid var(--card2);font-size:.78rem}
.bt-hayvan-satir:last-child{border-bottom:none}
```

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat(html): padok doluluk bar + seçim modu banner + action bar + m-bulk-transfer modal"
```

---

## Task 4: ui.js — State Değişkenleri + Doluluk Bar Render

**Files:**
- Modify: `js/ui.js` (~satır 5452)

- [ ] **Step 1: State değişkenlerini ekle**

`js/ui.js` içinde `let _pdHayvanIds = [];` satırının (satır ~5450) hemen altına ekle:

```javascript
// ── Toplu Transfer state ──
let _btSecimModu = false;
let _btSecilenIds = [];        // Cross-padok, filtreden bağımsız korunur
let _btModalSecilenIds = [];   // Modal içinde onaylanan hayvanlar
let _btHedefPadokId = null;    // Seçilen hedef padok ID
let _btEtiketMod = null;       // 'toplu' | 'tektek' | null
```

- [ ] **Step 2: renderPadokDolulukBar fonksiyonunu ekle**

`js/ui.js` içinde uygun bir yere (örn. `renderAnimals` fonksiyonundan sonra) ekle. `PADOKLAR` zaten `js/config.js`'den ui.js satır 13'te import edilmiştir — `window._padoklar` kullanma:

```javascript
function renderPadokDolulukBar() {
  const el = document.getElementById('padok-doluluk-bar');
  if (!el) return;

  // PADOKLAR config.js'den import edilmiş (ui.js satır 13) — window._ kullanma
  if (!PADOKLAR.length) { el.innerHTML = ''; return; }

  // Padok bazlı sayım — O(n) tek geçiş
  const animals = getState('animals') || [];
  const padokSayac = {};
  animals.forEach(h => {
    if (h.durum === 'Aktif' && h.padok_id) {
      padokSayac[h.padok_id] = (padokSayac[h.padok_id] || 0) + 1;
    }
  });

  el.innerHTML = PADOKLAR.map(p => {
    if (!p.kapasite) return '';
    const dolu = padokSayac[p.id] || 0;
    const kap = p.kapasite;
    const yuzde = Math.round((dolu / kap) * 100);
    const renk = yuzde >= 100 ? 'var(--red)' : yuzde >= 80 ? 'var(--amber)' : 'var(--green)';
    const padokAdi = (p.ad || '').replace(' Padok', '');
    return `<div class="pdoluluk-chip" onclick="setPadokFiltreBt('${p.id}','${p.ad}')" title="${p.ad}: ${dolu}/${kap}">
      <span class="pdoluluk-ad">${padokAdi}</span>
      <div class="pdoluluk-bar-wrap"><div class="pdoluluk-fill" style="width:${Math.min(yuzde,100)}%;background:${renk}"></div></div>
      <span class="pdoluluk-sayi" style="color:${renk}">${dolu}/${kap}</span>
    </div>`;
  }).join('');
}

function setPadokFiltreBt(padokId, padokAdi) {
  // Mevcut padok filtre select'ini güncelle
  const sel = document.getElementById('bi-padok') || document.getElementById('suru-padok-filtre');
  if (sel) {
    sel.value = padokAdi;
    sel.dispatchEvent(new Event('change'));
  }
}
```

**Not:** `PADOKLAR` config.js'den import edilmiş (ui.js satır 13). `getState('animals')` state management API — her zaman `|| []` ile kullan.

- [ ] **Step 3: loadPadokConfig'dan sonra doluluk bar'ı çağır**

`js/config.js` içinde `loadPadokConfig()` fonksiyonunda, `PADOKLAR = padoklar;` satırından hemen sonra ekle:

```javascript
renderPadokDolulukBar();
```

- [ ] **Step 4: Sürü verisi yüklenince bar'ı yenile**

Sürü listesi yüklenince (render fonksiyonunun sonunda) bar'ı güncelle:

```javascript
renderPadokDolulukBar();
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): state değişkenleri + padok doluluk bar render"
```

---

## Task 5: ui.js — Seçim Modu (Enter/Exit/Toggle)

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: enterBtSecimModu fonksiyonu ekle**

```javascript
function enterBtSecimModu() {
  _btSecimModu = true;
  _btSecilenIds = [];

  const btn = document.getElementById('bt-toggle-btn');
  if (btn) {
    btn.textContent = '✕ İptal';
    btn.style.borderColor = 'var(--red)';
    btn.style.color = 'var(--red)';
    btn.style.background = 'rgba(192,50,26,.1)';
  }

  const banner = document.getElementById('bt-banner');
  if (banner) banner.style.display = 'flex';

  const bar = document.getElementById('bt-action-bar');
  if (bar) bar.style.display = 'block';

  _btGuncelleActionBar();
  _btRenderSuru();  // Checkbox'ları göster
}
```

- [ ] **Step 2: exitBtSecimModu fonksiyonu ekle**

```javascript
function exitBtSecimModu() {
  _btSecimModu = false;
  _btSecilenIds = [];

  const btn = document.getElementById('bt-toggle-btn');
  if (btn) {
    btn.textContent = '🔀 Toplu Taşı';
    btn.style.borderColor = '';
    btn.style.color = '';
    btn.style.background = '';
  }

  const banner = document.getElementById('bt-banner');
  if (banner) banner.style.display = 'none';

  const bar = document.getElementById('bt-action-bar');
  if (bar) bar.style.display = 'none';

  const transferBtn = document.getElementById('bt-transfer-btn');
  if (transferBtn) transferBtn.disabled = true;

  _btRenderSuru();  // Checkbox'ları gizle
}
```

- [ ] **Step 3: btToggleSecimModu fonksiyonu ekle**

```javascript
function btToggleSecimModu() {
  if (_btSecimModu) exitBtSecimModu();
  else enterBtSecimModu();
}
```

- [ ] **Step 4: Seçim terk uyarısı — mevcut modal açma akışını koru**

Herhangi bir modal veya sekme geçişi yapılırken seçim modu aktifse uyarı ver. Mevcut `openM()` veya sekme değiştirme fonksiyonunun başına ekle:

```javascript
function _btSecimTerkUyari(callback) {
  if (!_btSecimModu || !_btSecilenIds.length) {
    if (_btSecimModu) exitBtSecimModu();
    callback();
    return;
  }
  if (confirm('Seçimin kaybolacak. Devam etmek istiyor musun?')) {
    exitBtSecimModu();
    callback();
  }
}
```

Mevcut sekme geçiş fonksiyonlarını (örn. `showTab`, `showSection`) başına `_btSecimTerkUyari(() => { ... })` sarmalıyla güncelle.

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): toplu transfer seçim modu enter/exit/toggle"
```

---

## Task 6: ui.js — Animal Card Checkbox + Seçim Toggle

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: _btRenderSuru fonksiyonu ekle**

Bu fonksiyon mevcut sürü render fonksiyonunu çağırır — checkbox görünürlüğü `.bt-mode` CSS class'ı ile yönetilir:

```javascript
function _btRenderSuru() {
  const suruEl = document.getElementById('suru-body') || document.getElementById('suru-list');
  if (!suruEl) return;
  if (_btSecimModu) {
    suruEl.classList.add('bt-mode');
  } else {
    suruEl.classList.remove('bt-mode');
  }
  // Seçili kartları highlight et
  document.querySelectorAll('.animal-card').forEach(card => {
    const id = card.dataset.id || card.dataset.hayvanId;
    if (id) card.classList.toggle('bt-selected', _btSecilenIds.includes(id));
  });
}
```

- [ ] **Step 2: Mevcut animal card render'ına checkbox ekle**

`js/ui.js` satır ~629'da animal card HTML'i üretiliyor. Card şablonu:
```
<div class="animal-card" onclick="openDet('${a.id}')">
```
`data-id` attribute'u yok — ekle. Checkbox'ı da başa ekle:

Mevcut card template'ini (satır ~629) şu hale getir:

```javascript
return `<div class="animal-card" data-id="${a.id}"
     onclick="if(_btSecimModu){_btKartTikla('${a.id}',event)}else{openDet('${a.id}')}">
  <input type="checkbox" class="bt-cb"
         ${_btSecilenIds.includes(a.id)?'checked':''}
         onchange="event.stopPropagation();btCbDegisti('${a.id}',this.checked)">
  ${seqHtml}<div class="avt">${init}</div>
  ...
```

`data-id` attribute'u _btRenderSuru tarafından highlight için kullanılır. `openDet` zaten mevcut onclick fonksiyonu (satır 629 doğrulandı).

Kart tıklama fonksiyonu:

```javascript
// Mevcut onclick fonksiyonuna (örn. openAnimalDet(id)) ekle:
function _btKartTikla(id, event) {
  event.stopPropagation();
  const idx = _btSecilenIds.indexOf(id);
  if (idx > -1) _btSecilenIds.splice(idx, 1);
  else _btSecilenIds.push(id);
  _btGuncelleActionBar();
  _btRenderSuru();
}
```

- [ ] **Step 3: btCbDegisti fonksiyonu ekle**

```javascript
function btCbDegisti(id, checked) {
  if (checked) {
    if (!_btSecilenIds.includes(id)) _btSecilenIds.push(id);
  } else {
    _btSecilenIds = _btSecilenIds.filter(x => x !== id);
  }
  _btGuncelleActionBar();
  _btRenderSuru();
}
```

- [ ] **Step 4: _btGuncelleActionBar fonksiyonu ekle**

```javascript
function _btGuncelleActionBar() {
  const count = _btSecilenIds.length;
  const countEl = document.getElementById('bt-count');
  if (countEl) countEl.textContent = `${count} hayvan seçildi`;

  // Kaç farklı kaynak padok?
  const suruData = getState('animals') || [];
  const padoklar = new Set(
    suruData.filter(h => _btSecilenIds.includes(h.id)).map(h => h.padok_id).filter(Boolean)
  );
  const padokCountEl = document.getElementById('bt-padok-count');
  if (padokCountEl) padokCountEl.textContent = padoklar.size > 0 ? `(${padoklar.size} padok)` : '';

  const transferBtn = document.getElementById('bt-transfer-btn');
  if (transferBtn) {
    transferBtn.disabled = count === 0;
    transferBtn.textContent = count > 0 ? `🔀 ${count} Taşı` : '🔀 Taşı';
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): animal card checkbox + seçim toggle + action bar güncelleme"
```

---

## Task 7: ui.js — m-bulk-transfer Modal Açma + Seçili Hayvanlar

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: openBulkTransfer fonksiyonu ekle**

```javascript
function openBulkTransfer() {
  if (!_btSecilenIds.length) return;

  _btModalSecilenIds = [..._btSecilenIds];
  _btHedefPadokId = null;
  _btEtiketMod = null;

  // Grup filtresi dropdown'ını doldur (GRUP_PADOK ui.js satır 13'te import edilmiş)
  const grupSel = document.getElementById('bt-f-grup');
  if (grupSel) {
    const gruplar = Object.keys(GRUP_PADOK);
    grupSel.innerHTML = '<option value="">Tüm Gruplar</option>' +
      gruplar.map(g => `<option>${g}</option>`).join('');
  }

  // Kaynak padok dropdown'ını doldur (PADOKLAR ui.js satır 13'te import edilmiş)
  const kaynakSel = document.getElementById('bt-kaynak-padok-sel');
  if (kaynakSel) {
    kaynakSel.innerHTML = '<option value="">— Padok Seç —</option>' +
      PADOKLAR.map(p => `<option value="${p.id}">${p.ad}</option>`).join('');
  }

  // Serbest liste'yi doldur
  _btRenderSerbestListe();

  // Seçili hayvanları render et
  _btRenderSeciliHayvanlar();

  // Hedef padok listesini render et
  _btRenderHedefPadoklar();

  // Özeti sıfırla
  document.getElementById('bt-ozet').style.display = 'none';
  document.getElementById('bt-etiket-bolum').style.display = 'none';
  document.getElementById('bt-onay-btn').disabled = true;

  openM('m-bulk-transfer');
  exitBtSecimModu();
}
```

- [ ] **Step 2: _btRenderSeciliHayvanlar fonksiyonu ekle**

```javascript
function _btRenderSeciliHayvanlar() {
  const liste = document.getElementById('bt-secili-liste');
  const sayac = document.getElementById('bt-secili-sayac');
  if (!liste) return;

  const suruData = getState('animals') || [];
  const hayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));

  sayac.textContent = `${hayvanlar.length} hayvan`;

  if (!hayvanlar.length) {
    liste.innerHTML = '<div style="color:var(--ink3);font-size:.78rem;padding:8px;text-align:center">Hayvan seçilmedi</div>';
    return;
  }

  liste.innerHTML = hayvanlar.map(h => `
    <div class="bt-hayvan-satir">
      <span style="font-weight:600;font-size:.8rem">${h.kupe || h.id}</span>
      <span style="font-size:.68rem;color:var(--ink3);flex:1;margin:0 6px">${h.grup || ''} · ${h.padok || ''}</span>
      <button onclick="btSecilidenKaldir('${h.id}')" style="background:none;border:none;color:var(--ink3);cursor:pointer;font-size:1rem;padding:2px 4px;line-height:1" title="Çıkar">×</button>
    </div>
  `).join('');
}
```

- [ ] **Step 3: btSecilidenKaldir fonksiyonu ekle**

```javascript
function btSecilidenKaldir(id) {
  _btModalSecilenIds = _btModalSecilenIds.filter(x => x !== id);
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  _btGuncelleOzet();
  if (!_btModalSecilenIds.length) {
    document.getElementById('bt-onay-btn').disabled = true;
  }
}
```

- [ ] **Step 4: Tab switch — mevcut `bulkTabSwitch` yeniden kullan**

`btTabSwitch` yeni fonksiyon yazmak yerine `forms.js:1547`'deki mevcut `bulkTabSwitch(prefix, tab)` fonksiyonunu `'bt'` prefix ile çağır. Yeni bir wrapper fonksiyon gerekmez — handler kayıtlarında direkt `bulkTabSwitch('bt', tab)` kullanılır (bkz. Task 11).

- [ ] **Step 5: _btRenderSerbestListe fonksiyonu ekle**

```javascript
function _btRenderSerbestListe() {
  const el = document.getElementById('bt-serbest-liste');
  if (!el) return;
  const suruData = getState('animals') || [];
  el.innerHTML = suruData.filter(h => h.durum === 'Aktif').map(h => `
    <label style="display:flex;align-items:center;gap:8px;padding:5px 6px;border-radius:6px;cursor:pointer;font-size:.78rem">
      <input type="checkbox" value="${h.id}" 
             ${_btModalSecilenIds.includes(h.id)?'checked':''}
             onchange="btSerbestSec('${h.id}',this.checked)"
             style="accent-color:var(--blue);width:16px;height:16px">
      <span style="font-weight:600">${h.kupe||h.id}</span>
      <span style="font-size:.68rem;color:var(--ink3)">${h.grup||''} · ${h.padok||''}</span>
    </label>
  `).join('');
}

function btSerbestAra(q) {
  const suruData = getState('animals') || [];
  const el = document.getElementById('bt-serbest-liste');
  if (!el) return;
  const filtre = q.toLowerCase();
  el.querySelectorAll('label').forEach(lbl => {
    lbl.style.display = lbl.textContent.toLowerCase().includes(filtre) ? '' : 'none';
  });
}

function btSerbestSec(id, checked) {
  if (checked && !_btModalSecilenIds.includes(id)) _btModalSecilenIds.push(id);
  else if (!checked) _btModalSecilenIds = _btModalSecilenIds.filter(x => x !== id);
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  _btGuncelleOzet();
}
```

- [ ] **Step 6: Padok tab fonksiyonları ekle**

```javascript
function btKaynakPadokSec(padokId) {
  // Sadece state'i güncelle, getir butonuyla hayvanlar çekilecek
}

function btGetKaynakHayvanlar() {
  const padokId = document.getElementById('bt-kaynak-padok-sel').value;
  if (!padokId) { toast('⚠️ Önce kaynak padok seçin', true); return; }
  const suruData = getState('animals') || [];
  const hayvanlar = suruData.filter(h => h.padok_id === padokId && h.durum === 'Aktif');
  // Seçili listeye ekle (varsa zaten varsa ekleme)
  hayvanlar.forEach(h => {
    if (!_btModalSecilenIds.includes(h.id)) _btModalSecilenIds.push(h.id);
  });
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  toast(`✓ ${hayvanlar.length} hayvan eklendi`);
}

function btApplyFiltre() {
  const grup = document.getElementById('bt-f-grup').value;
  const cinsiyet = document.getElementById('bt-f-cinsiyet').value;
  const yasMin = parseInt(document.getElementById('bt-f-yas-min').value) || 0;
  const yasMax = parseInt(document.getElementById('bt-f-yas-max').value) || 9999;
  const bugun = Date.now();

  const suruData = getState('animals') || [];
  const sonuc = suruData.filter(h => {
    if (h.durum !== 'Aktif') return false;
    if (grup && h.grup !== grup) return false;
    if (cinsiyet && h.cinsiyet !== cinsiyet) return false;
    if (h.dogum) {
      const ay = Math.floor((bugun - new Date(h.dogum).getTime()) / (86400000 * 30));
      if (ay < yasMin || ay > yasMax) return false;
    }
    return true;
  });

  sonuc.forEach(h => {
    if (!_btModalSecilenIds.includes(h.id)) _btModalSecilenIds.push(h.id);
  });
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  toast(`✓ ${sonuc.length} hayvan eklendi`);
}
```

- [ ] **Step 7: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): openBulkTransfer + seçili hayvanlar render + tab switch + filtre/serbest fonksiyonları"
```

---

## Task 8: ui.js — Hedef Padok Listesi + Özet

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: _btGrupUygunMu yardımcı fonksiyonu ekle**

```javascript
function _btGrupUygunMu(padok, gruplar) {
  if (!gruplar.length) return true;
  // GRUP_PADOK config.js'den ui.js satır 13'te import edilmiş — window._ değil
  return gruplar.every(g => {
    const uygunAdlar = GRUP_PADOK[g] || [];
    return uygunAdlar.length === 0 || uygunAdlar.includes(padok.ad);
  });
}

function _btBesiPadokMu(padok) {
  return (padok.ad || '').toLowerCase().includes('besi');
}
```

- [ ] **Step 2: _btRenderHedefPadoklar fonksiyonu ekle**

```javascript
function _btRenderHedefPadoklar() {
  const el = document.getElementById('bt-hedef-liste');
  if (!el) return;

  // PADOKLAR config.js'den import edilmiş (ui.js satır 13)
  const suruData = getState('animals') || [];

  if (!_btModalSecilenIds.length) {
    el.innerHTML = '<div style="color:var(--ink3);font-size:.78rem">Önce hayvan seçin</div>';
    return;
  }

  const secilenHayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  const gruplar = [...new Set(secilenHayvanlar.map(h => h.grup).filter(Boolean))];

  // Kaynakları bul (kaynak padokları hedef listesinden çıkarmak için)
  const kaynakPadoklar = new Set(secilenHayvanlar.map(h => h.padok_id).filter(Boolean));

  el.innerHTML = PADOKLAR.map(p => {
    const dolu = suruData.filter(h => h.padok_id === p.id && h.durum === 'Aktif').length;
    const kap = p.kapasite;
    const yuzde = kap ? Math.round((dolu / kap) * 100) : 0;
    const tamDolu = kap && dolu >= kap;
    const uyari = kap && yuzde >= 80 && !tamDolu;
    const uygun = _btGrupUygunMu(p, gruplar);
    const besi = _btBesiPadokMu(p);

    // Kaynak padok ise gösterme (tek kaynaktan geliyorsa)
    if (kaynakPadoklar.size === 1 && kaynakPadoklar.has(p.id)) return '';

    const disabled = tamDolu || (!uygun && !besi);
    const sinif = yuzde >= 100 ? 'dolu' : yuzde >= 80 ? 'uyari' : 'uygun';
    const renk = yuzde >= 100 ? 'var(--red)' : yuzde >= 80 ? 'var(--amber)' : 'var(--green)';
    const selected = _btHedefPadokId === p.id;

    let badge = '';
    if (tamDolu) badge = '<span style="font-size:.6rem;color:var(--red);font-weight:700">DOLU</span>';
    else if (!uygun && !besi) badge = '<span style="font-size:.6rem;color:var(--red)">❌ Uyumsuz</span>';
    else if (!uygun && besi) badge = '<span style="font-size:.6rem;color:var(--amber)">⚠️ Etiket gerekli</span>';
    else if (uyari) badge = '<span style="font-size:.6rem;color:var(--amber)">⚠️ Dolmak üzere</span>';
    else badge = '<span style="font-size:.6rem;color:var(--green3)">✅ Uyumlu</span>';

    return `<div class="bt-padok-opt ${disabled?'disabled':''} ${selected?'selected':''}"
                 onclick="${disabled?'':'btHedefSec(\''+p.id+'\')'}">
      <span class="bpo-ad">${p.ad}</span>
      ${badge}
      ${kap ? `<div>
        <div class="bpo-bar-wrap"><div class="bpo-bar-fill" style="width:${Math.min(yuzde,100)}%;background:${renk}"></div></div>
        <div style="font-size:.6rem;color:${renk};text-align:right">${dolu}/${kap}</div>
      </div>` : ''}
    </div>`;
  }).join('');
}
```

- [ ] **Step 3: btHedefSec fonksiyonu ekle**

```javascript
function btHedefSec(padokId) {
  _btHedefPadokId = padokId;
  _btGuncelleOzet();
  _btRenderHedefPadoklar();  // Selected class'ı güncelle
}
```

- [ ] **Step 4: _btGuncelleOzet fonksiyonu ekle**

```javascript
function _btGuncelleOzet() {
  const ozet = document.getElementById('bt-ozet');
  const etiketBolum = document.getElementById('bt-etiket-bolum');
  const onayBtn = document.getElementById('bt-onay-btn');

  if (!_btModalSecilenIds.length || !_btHedefPadokId) {
    ozet.style.display = 'none';
    etiketBolum.style.display = 'none';
    onayBtn.disabled = true;
    return;
  }

  // PADOKLAR config.js'den import edilmiş (ui.js satır 13)
  const suruData = getState('animals') || [];
  const hedef = PADOKLAR.find(p => p.id === _btHedefPadokId);
  if (!hedef) return;

  const secilenHayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  const gruplar = [...new Set(secilenHayvanlar.map(h => h.grup).filter(Boolean))];
  const dolu = suruData.filter(h => h.padok_id === hedef.id && h.durum === 'Aktif').length;
  const kap = hedef.kapasite;
  const uygun = _btGrupUygunMu(hedef, gruplar);
  const besi = _btBesiPadokMu(hedef);
  const kapUygun = !kap || (dolu + _btModalSecilenIds.length <= kap);
  const yeniDoluluk = kap ? Math.round(((dolu + _btModalSecilenIds.length) / kap) * 100) : 0;

  // Özet göster
  ozet.style.display = 'block';
  document.getElementById('bt-ozet-transfer').textContent =
    `${_btModalSecilenIds.length} hayvan → ${hedef.ad}`;
  document.getElementById('bt-ozet-transfer').className = 'ozet-value ok';

  const kapEl = document.getElementById('bt-ozet-kap');
  if (!kap) {
    kapEl.textContent = 'Kapasite tanımsız';
    kapEl.style.color = 'var(--ink3)';
  } else if (kapUygun) {
    kapEl.textContent = `✓ ${dolu + _btModalSecilenIds.length}/${kap} (%${yeniDoluluk})`;
    kapEl.style.color = yeniDoluluk >= 80 ? 'var(--amber)' : 'var(--green3)';
  } else {
    kapEl.textContent = `✗ ${dolu + _btModalSecilenIds.length}/${kap} — Kapasite aşımı!`;
    kapEl.style.color = 'var(--red)';
  }

  const gpEl = document.getElementById('bt-ozet-grup');
  if (uygun) {
    gpEl.textContent = '✓ Tüm hayvanlar için uyumlu';
    gpEl.style.color = 'var(--green3)';
  } else if (besi) {
    gpEl.textContent = '⚠️ Etiket gerekli (besi transferi)';
    gpEl.style.color = 'var(--amber)';
  } else {
    gpEl.textContent = '✗ Grup uyumsuz';
    gpEl.style.color = 'var(--red)';
  }

  // Besi etiket bölümü
  const etiketGerekli = besi && !uygun;
  etiketBolum.style.display = etiketGerekli ? 'block' : 'none';
  if (etiketGerekli) _btRenderEtiketTekkek();

  // Onay butonu
  const etiketOk = !etiketGerekli || _btEtiketleriKontrolEt();
  onayBtn.disabled = !(kapUygun && (uygun || besi) && etiketOk);
  onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`;
}
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): hedef padok listesi render + özet + grup/kapasite uyum kontrolü"
```

---

## Task 9: ui.js — Besi Etiket Akışı

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: _btRenderEtiketTekkek fonksiyonu ekle**

```javascript
function _btRenderEtiketTekkek() {
  const el = document.getElementById('bt-etiket-tektek-liste');
  if (!el) return;

  const suruData = getState('animals') || [];
  const hayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));

  el.innerHTML = hayvanlar.map(h => `
    <div style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:.78rem;border-bottom:1px solid var(--card2)">
      <span style="font-weight:600;min-width:60px">${h.kupe||h.id}</span>
      <span style="font-size:.68rem;color:var(--ink3);flex:1">${h.grup||''}</span>
      <label style="display:inline-flex;align-items:center;gap:4px;cursor:pointer">
        <input type="checkbox" data-hayvan="${h.id}" data-etiket="kisir"
               onchange="btEtiketTekkekDegisti()" style="accent-color:var(--blue)"> Kısır
      </label>
      <label style="display:inline-flex;align-items:center;gap:4px;cursor:pointer">
        <input type="checkbox" data-hayvan="${h.id}" data-etiket="satista"
               onchange="btEtiketTekkekDegisti()" style="accent-color:var(--blue)"> Satışta
      </label>
    </div>
  `).join('');
}
```

- [ ] **Step 2: btEtiketTopluDegisti fonksiyonu ekle**

```javascript
function btEtiketTopluDegisti() {
  _btEtiketMod = 'toplu';

  // Tek tek seçimleri sıfırla
  document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]')
    .forEach(cb => { cb.checked = false; });

  _btGuncelleOzet();
}
```

- [ ] **Step 3: btEtiketTekkekDegisti fonksiyonu ekle**

```javascript
function btEtiketTekkekDegisti() {
  _btEtiketMod = 'tektek';

  // Toplu seçimleri sıfırla
  document.getElementById('bt-et-toplu-kisir').checked = false;
  document.getElementById('bt-et-toplu-satista').checked = false;

  _btGuncelleOzet();
}
```

- [ ] **Step 4: _btEtiketleriKontrolEt fonksiyonu ekle**

```javascript
function _btEtiketleriKontrolEt() {
  const topluKisir = document.getElementById('bt-et-toplu-kisir')?.checked;
  const topluSatista = document.getElementById('bt-et-toplu-satista')?.checked;

  if (topluKisir || topluSatista) return true;

  // Tek tek: her hayvan için en az bir etiket seçili mi?
  const tekTekCbs = document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]');
  if (!tekTekCbs.length) return false;

  const hayvanEtiketler = {};
  tekTekCbs.forEach(cb => {
    if (cb.checked) {
      hayvanEtiketler[cb.dataset.hayvan] = true;
    }
  });

  return _btModalSecilenIds.every(id => hayvanEtiketler[id]);
}

function _btEtiketleriBir() {
  // Etiketleri birleştirip döndür: toplu mod → tüm hayvanlara tek array
  //                                  tektek mod → her hayvan için ayrı map
  const topluKisir = document.getElementById('bt-et-toplu-kisir')?.checked;
  const topluSatista = document.getElementById('bt-et-toplu-satista')?.checked;

  if (topluKisir || topluSatista) {
    const etiketler = [];
    if (topluKisir) etiketler.push('kisir');
    if (topluSatista) etiketler.push('satista');
    return { mod: 'toplu', etiketler };
  }

  const tekTekCbs = document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]');
  const map = {};
  tekTekCbs.forEach(cb => {
    if (cb.checked) {
      if (!map[cb.dataset.hayvan]) map[cb.dataset.hayvan] = [];
      map[cb.dataset.hayvan].push(cb.dataset.etiket);
    }
  });
  return { mod: 'tektek', map };
}
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): besi etiket akışı — toplu/tektek seçim, validasyon"
```

---

## Task 10: ui.js — btTransferOnayla (RPC + Hata Yönetimi)

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: btTransferOnayla fonksiyonu ekle**

```javascript
async function btTransferOnayla() {
  if (!_btModalSecilenIds.length || !_btHedefPadokId) return;

  const onayBtn = document.getElementById('bt-onay-btn');
  onayBtn.disabled = true;
  onayBtn.textContent = '⏳ Taşınıyor…';

  try {
    // Etiket parametresini hazırla (PADOKLAR config.js'den import edilmiş)
    let etiketParam = null;
    const hedef = PADOKLAR.find(p => p.id === _btHedefPadokId);
    const suruData = getState('animals') || [];
    const secilenHayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
    const gruplar = [...new Set(secilenHayvanlar.map(h => h.grup).filter(Boolean))];

    if (_btBesiPadokMu(hedef) && !_btGrupUygunMu(hedef, gruplar)) {
      const etiketBilgi = _btEtiketleriBir();
      if (etiketBilgi.mod === 'toplu') {
        etiketParam = etiketBilgi.etiketler;
      } else {
        // Tektek mod: tek hayvan varsa direkt, birden fazlaysa ortak etiketleri bul
        const tumEtiketler = Object.values(etiketBilgi.map).flat();
        etiketParam = [...new Set(tumEtiketler)];
      }
    }

    const { data, error } = await supabase.rpc('padok_degistir_toplu', {
      p_hayvan_ids:    _btModalSecilenIds,
      p_yeni_padok_id: _btHedefPadokId,
      p_etiketler:     etiketParam
    });

    if (error) throw error;

    if (!data.success) {
      if (data.error === 'kapasite_dolu') {
        toast(`❌ Kapasite dolu: ${data.detay || ''}. Transfer iptal edildi.`, true);
      } else {
        toast(`❌ Transfer başarısız: ${data.mesaj || data.error || 'Hata'}`, true);
      }
      onayBtn.disabled = false;
      onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`;
      return;
    }

    // Başarılı
    toast(`✅ ${data.hayvan_sayisi} hayvan ${data.yeni_padok}'a taşındı`);
    closeM('m-bulk-transfer');

    // Sürü listesini yenile
    if (typeof loadAnimals === 'function') await loadAnimals();
    if (typeof renderPadokDolulukBar === 'function') renderPadokDolulukBar();

  } catch (err) {
    console.error('btTransferOnayla hata:', err);
    toast('❌ Beklenmeyen hata: ' + (err.message || err), true);
    onayBtn.disabled = false;
    onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`;
  }
}
```

- [ ] **Step 2: Mevcut padokTopluTasi'ı yeni modala yönlendir**

`js/ui.js` içinde `padokTopluTasi()` fonksiyonunu bul (~satır 5524) ve güncelle:

```javascript
function padokTopluTasi() {
  if (!_pdHayvanIds.length) { toast('⚠️ Lütfen en az bir hayvan seçin', true); return; }
  _btSecilenIds = [..._pdHayvanIds];
  _btModalSecilenIds = [..._pdHayvanIds];
  _btHedefPadokId = null;
  openBulkTransfer();
}
```

- [ ] **Step 3: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): btTransferOnayla RPC çağrısı + hata yönetimi + padokTopluTasi yönlendirme"
```

---

## Task 11: handlers.js — Yeni Handler Kayıtları

**Files:**
- Modify: `js/utils/handlers.js` (~satır 243)

- [ ] **Step 1: Yeni handler'ları ekle**

`'padok-transfer-onay': () => padokTransferOnayla()` satırının hemen altına ekle:

```javascript
// ── Toplu Transfer ──
'bt-toggle-mode':  () => btToggleSecimModu(),
'bt-transfer':     () => { if (_btSecilenIds.length) openBulkTransfer(); },
'bt-cancel':       () => exitBtSecimModu(),
'close-bulk-transfer': () => closeM('m-bulk-transfer'),
// bulkTabSwitch(prefix, tab) forms.js:1547'de mevcut — yeni fonksiyon yazmak gerekmez
'bt-tab-padok':    () => bulkTabSwitch('bt', 'padok'),
'bt-tab-filtre':   () => bulkTabSwitch('bt', 'filtre'),
'bt-tab-serbest':  () => bulkTabSwitch('bt', 'serbest'),
```

- [ ] **Step 2: Commit**

```bash
git add js/utils/handlers.js
git commit -m "feat(handlers): toplu transfer bt-* handler kayıtları"
```

---

## Task 12: Son Test + Push

- [ ] **Step 1: Tarayıcıda manuel test — seçim modu**

1. Sürü dashboardını aç
2. `[🔀 Toplu Taşı]` butonuna tıkla → seçim modu aktif olmalı, banner görünmeli
3. 3 hayvan kartına tıkla → highlight + action bar sayacı güncellenmeli
4. Padok filtresi değiştir → seçim korunmalı
5. `[✕ İptal]` → seçim sıfırlanmalı, normal görünüme dönmeli

- [ ] **Step 2: Tarayıcıda manuel test — transfer modal**

1. 2-3 hayvan seç → `[🔀 N Taşı]` tıkla → modal açılmalı
2. Hedef padok listesini gör → kapasite barları, uyum badge'leri doğru renkte mi?
3. Uyumlu padok seç → özet görünmeli, `[Taşı]` aktif olmalı
4. Uyumsuz (❌) padok tıklanamaz olmalı
5. Besi padok seç (etiket gerekiyorsa) → etiket bölümü açılmalı

- [ ] **Step 3: Tarayıcıda manuel test — kapasite uyarısı**

Dolu bir padoğu hedef seç:
- Hedef listede DOLU göstermeli, seçilememeli
- Eğer RPC testinde hedef gerçekten doluysa → `kapasite_dolu` hatası toast olarak görünmeli

- [ ] **Step 4: Tarayıcıda manuel test — besi etiket**

1. Sağmal inek seç → hedef: Besi Padok → etiket bölümü açılmalı
2. Toplu ata: Kısır seç → `[Taşı]` aktif
3. Transfer → `hayvanlar.etiketler` kolonunda `{kisir}` görünmeli (Supabase Dashboard)

- [ ] **Step 5: Git push**

```bash
git push origin main
```

---

## Notlar DeepSeek İçin

1. **`getState('animals')` YOK** — Hayvan verisi `getState('animals')` ile gelir (`ui.js:1684`). Tüm `getState('animals')` kullanımlarını `getState('animals') || []` ile değiştir.

2. **`PADOKLAR` kullan** — `js/config.js:60`'ta `let PADOKLAR = []` tanımlı, `loadPadokConfig()` içinde `PADOKLAR = padoklar` ile doldurulur. `ui.js` satır 13'te import edilmiş — direkt `PADOKLAR` kullan. `window._padoklar` gibi yeni bir global **oluşturma**.

3. **`loadSuru()` YOK** — Sürü listesini yenileyen fonksiyon `loadAnimals()` (`ui.js:568`). `btTransferOnayla` içinde `loadAnimals()` kullan.

4. **`islem_log` kolon isimleri** — Tablo şeması (`ground_truth.sql:295-313`):
   - `tip` (NOT NULL) — `islem_tipi` değil
   - `ana_hayvan_id` — `hayvan_id` değil
   - `ref_id` — hayvan ID'sini buraya da yaz
   - `snapshot jsonb NOT NULL` — `'{}'::jsonb` gönder
   - `kullanici_notu` — `aciklama` değil
   - `tarih` — `created_at` değil, varsayılan `now()` var

5. **`updated_at = now()`** — Tüm `UPDATE hayvanlar` ifadelerine ekle (`ground_truth.sql:7096`'da mevcut versiyonda var).

6. **openM / closeM:** Mevcut modal açma/kapama fonksiyonları. İmzaları değiştirilmeden kullanılır.

7. **Animal card HTML template:** `_btRenderSuru` içinde checkbox eklemek için mevcut card template'i bul ve checkbox'ı `data-id` attribute'u ile birlikte ekle.

8. **ground_truth.sql satır numaraları (doğrulanmış):**
   - `padok_degistir`: satır 7059-7127
   - `padok_degistir_toplu`: satır 7133-7217
   - `hayvanlar` CREATE TABLE: grep ile bul — `grep -n "CREATE TABLE.*hayvanlar" ground_truth.sql`

9. **Eski akış temizliği:** `padokTopluTasi()` yeni modala yönlendirildikten sonra `_pdTransferAcSelector()` ve `padokTransferOnayla()` fonksiyonları ve `m-padok-transfer` modal'ı silinebilir. Ancak `padokTekliTasi()` hala `_pdTransferAcSelector()`'ı kullanıyor — bunu da yeni akışa yönlendir veya eski akışı koru.

10. **Seçim terk uyarısı:** En basit yaklaşım — `openM()` fonksiyonunu override etmek yerine ana sekme değiştirme handler'larına (`pg-suru` dışına çıkış) `_btSecimTerkUyari` kontrolü ekle.

11. **`PADOKLAR` ve `GRUP_PADOK` import** — `js/ui.js` satır 13'te her ikisi de config.js'den import edilmiş. `window.PADOKLAR`, `window.GRUP_PADOK`, `window._padoklar` gibi global erişim kullanma.

12. **`padoklar.kapasite` production'da NULL** — Tüm mevcut padokların kapasite değeri NULL. Kapasite sistemi admin bir değer girene kadar `renderPadokDolulukBar`'da `if (!p.kapasite) return ''` ile chip gösterilmez. Bu beklenen davranış — kapasite kontrolü devreye girmeden transfer çalışmaya devam eder.

13. **`bulkTabSwitch(prefix, tab)` — forms.js:1547** — Zaten mevcut. `btTabSwitch` adında yeni fonksiyon yazmak yerine `bulkTabSwitch('bt', 'padok')` gibi çağır.
