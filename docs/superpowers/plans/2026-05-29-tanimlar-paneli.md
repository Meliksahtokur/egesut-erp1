# Tanımlar Paneli Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hastalık, ilaç ve stok kategorileri için CRUD yönetim paneli — kullanıcı DB'ye girmeden tanım ekleyip düzenleyebilsin.

**Architecture:** Stok paneli ile birebir aynı pattern: full-screen slide-in panel + sekmeli yapı (Hastalıklar/İlaçlar/Kategoriler). Her sekme kart listesi + inline form. Backend'de 10 RPC + 1 yeni tablo (`stok_kategorileri`). IDB sync mevcut pattern'i takip eder.

**Tech Stack:** Vanilla JS, Supabase (PostgreSQL RPC), IndexedDB (idbClearAndPut), mevcut CSS sınıfları.

**Spec:** `docs/superpowers/specs/2026-05-29-tanimlar-paneli-design.md`

---

## File Map

| Dosya | Değişiklik | Sorumluluk |
|-------|-----------|------------|
| `supabase/migrations/YYYYMMDD_tanimlar_crud.sql` | CREATE | Yeni tablo + 10 RPC + seed data + RLS |
| `index.html` | MODIFY (~line 492) | Tanımlar butonu + slide-in panel HTML |
| `js/app.js` | MODIFY (~line 57) | `_tanimlarTab` global state |
| `js/api.js` | MODIFY (~line 10, ~line 305) | TABLES + FETCHERS'a `stok_kategorileri` ekleme |
| `js/ui.js` | MODIFY (stok bölümü sonrası ~line 2140) | Panel render fonksiyonları |
| `js/utils/handlers.js` | MODIFY (~line 95) | Action handler'lar |

---

### Task 1: Migration — stok_kategorileri tablosu + RPC'ler + seed data

**Files:**
- Create: `supabase/migrations/20260529000001_tanimlar_crud.sql`

- [ ] **Step 1: stok_kategorileri tablosu + seed data SQL yaz**

```sql
-- ══════════════════════════════════════════════════════════════
-- MIGRATION: Tanımlar Paneli — CRUD RPC'ler + stok_kategorileri
-- ══════════════════════════════════════════════════════════════

-- 1. STOK_KATEGORİLERİ TABLOSU
CREATE TABLE IF NOT EXISTS public.stok_kategorileri (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad         text UNIQUE NOT NULL,
  sira       integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.stok_kategorileri IS 'Stok kategori tanımları — Tanımlar panelinden yönetilir';

-- RLS
ALTER TABLE public.stok_kategorileri ENABLE ROW LEVEL SECURITY;
CREATE POLICY stok_kat_select ON public.stok_kategorileri FOR SELECT USING (true);
CREATE POLICY stok_kat_all    ON public.stok_kategorileri FOR ALL    USING (true) WITH CHECK (true);

-- Seed — standart kategoriler
INSERT INTO public.stok_kategorileri (ad, sira) VALUES
  ('Antibiyotik', 1),
  ('NSAID', 2),
  ('Hormon', 3),
  ('Vitamin', 4),
  ('Antiparaziter', 5),
  ('Diğer İlaç', 6),
  ('Aşı', 7),
  ('Sperma', 8),
  ('Yem', 9),
  ('Sarf', 10),
  ('Ekipman', 11),
  ('Diğer', 12)
ON CONFLICT (ad) DO NOTHING;
```

- [ ] **Step 2: disease RPC'leri yaz**

```sql
-- 2. DISEASE RPC'LER
CREATE OR REPLACE FUNCTION public.disease_ekle(
  p_name     text,
  p_category text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hastalık zaten var');
  END IF;
  INSERT INTO diseases (name, category) VALUES (p_name, p_category) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_guncelle(
  p_id       uuid,
  p_name     text,
  p_category text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir hastalık var');
  END IF;
  UPDATE diseases SET name = p_name, category = p_category WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_sil(
  p_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_aktif integer;
  v_kapali integer;
BEGIN
  SELECT
    COUNT(*) FILTER (WHERE status = 'active'),
    COUNT(*) FILTER (WHERE status = 'closed')
  INTO v_aktif, v_kapali
  FROM cases WHERE disease_id = p_id;

  IF v_aktif > 0 OR v_kapali > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      format('Bu hastalığa ait %s vaka var (%s aktif, %s kapalı), silinemez', v_aktif + v_kapali, v_aktif, v_kapali));
  END IF;
  DELETE FROM diseases WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;
```

- [ ] **Step 3: drug RPC'leri yaz**

```sql
-- 3. DRUG RPC'LER
CREATE OR REPLACE FUNCTION public.drug_ekle(
  p_name          text,
  p_default_unit  text DEFAULT NULL,
  p_default_route text DEFAULT NULL,
  p_stock_item_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu ilaç zaten var');
  END IF;
  INSERT INTO drugs (name, default_unit, default_route, stock_item_id)
  VALUES (p_name, p_default_unit, p_default_route, p_stock_item_id)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_guncelle(
  p_id             uuid,
  p_name           text,
  p_default_unit   text DEFAULT NULL,
  p_default_route  text DEFAULT NULL,
  p_stock_item_id  text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir ilaç var');
  END IF;
  UPDATE drugs SET name = p_name, default_unit = p_default_unit,
    default_route = p_default_route, stock_item_id = p_stock_item_id
  WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_sil(
  p_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
  v_count   integer;
BEGIN
  SELECT stock_item_id INTO v_stok_id FROM drugs WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı');
  END IF;
  IF v_stok_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM drug_administrations WHERE stok_id = v_stok_id;
    IF v_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        format('Bu ilaç %s tedavi uygulamasında kullanılmış, silinemez', v_count));
    END IF;
  END IF;
  DELETE FROM drugs WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;
```

- [ ] **Step 4: kategori RPC'leri yaz**

```sql
-- 4. KATEGORİ RPC'LER
CREATE OR REPLACE FUNCTION public.kategori_ekle(
  p_ad text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_ad)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kategori zaten var');
  END IF;
  INSERT INTO stok_kategorileri (ad, sira)
  VALUES (p_ad, COALESCE((SELECT MAX(sira) FROM stok_kategorileri), 0) + 1)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_guncelle(
  p_id     uuid,
  p_new_ad text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_old_ad text;
BEGIN
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_new_ad) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir kategori var');
  END IF;
  SELECT ad INTO v_old_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı');
  END IF;
  UPDATE stok SET kategori = p_new_ad WHERE kategori = v_old_ad;
  UPDATE stok_kategorileri SET ad = p_new_ad WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_sil(
  p_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_ad    text;
  v_count integer;
BEGIN
  SELECT ad INTO v_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı');
  END IF;
  SELECT COUNT(*) INTO v_count FROM stok WHERE kategori = v_ad;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      format('Bu kategoride %s ürün var, silinemez', v_count));
  END IF;
  DELETE FROM stok_kategorileri WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;
```

- [ ] **Step 5: seed_defaults RPC yaz**

```sql
-- 5. SEED_DEFAULTS — varsayılana dön
CREATE OR REPLACE FUNCTION public.seed_defaults(
  p_tip text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0;
BEGIN
  IF p_tip = 'diseases' THEN
    WITH ins AS (
      INSERT INTO diseases (name, category) VALUES
        ('Mastitis', 'Meme'),
        ('Laminitis', 'Ayak'),
        ('Metritis', 'Üreme'),
        ('Retensio', 'Üreme'),
        ('Ketozis', 'Metabolik'),
        ('Hipokalsemi', 'Metabolik'),
        ('Pnömoni', 'Solunum'),
        ('İshal', 'Sindirim'),
        ('Neonatal Zayıflık', 'Buzağı'),
        ('Göbek İltihabı', 'Buzağı')
      ON CONFLICT (name) DO NOTHING
      RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;

  ELSIF p_tip = 'drugs' THEN
    WITH ins AS (
      INSERT INTO drugs (name, default_unit, default_route) VALUES
        ('Makrovil', 'ml', 'IM'),
        ('Enrolen', 'ml', 'IM'),
        ('Florkem', 'ml', 'IM'),
        ('Penicilin', 'ml', 'IM'),
        ('Oksitetrasiklin', 'ml', 'IM'),
        ('Meloksikam', 'ml', 'IV'),
        ('Flunixin', 'ml', 'IV'),
        ('Deksametazon', 'ml', 'IM'),
        ('Kalsiyum Boroglukonat', 'ml', 'IV'),
        ('B12 Vitamini', 'ml', 'IM'),
        ('AD3E Vitamini', 'ml', 'IM'),
        ('Albendazol', 'ml', 'PO'),
        ('İvermektin', 'ml', 'SC')
      ON CONFLICT (name) DO NOTHING
      RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;

  ELSIF p_tip = 'kategoriler' THEN
    WITH ins AS (
      INSERT INTO stok_kategorileri (ad, sira) VALUES
        ('Antibiyotik', 1), ('NSAID', 2), ('Hormon', 3), ('Vitamin', 4),
        ('Antiparaziter', 5), ('Diğer İlaç', 6), ('Aşı', 7), ('Sperma', 8),
        ('Yem', 9), ('Sarf', 10), ('Ekipman', 11), ('Diğer', 12)
      ON CONFLICT (ad) DO NOTHING
      RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;

  ELSE
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz tip: diseases | drugs | kategoriler');
  END IF;

  RETURN jsonb_build_object('ok', true, 'eklenen', v_count);
END;
$$;
```

- [ ] **Step 6: GRANT'lar**

```sql
-- 6. GRANT
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stok_kategorileri TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_ekle(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_guncelle(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_ekle(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_guncelle(uuid, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_ekle(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_guncelle(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seed_defaults(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
```

- [ ] **Step 7: Migration'ı deploy et**

Run: `supabase_migrate` ile SQL'i gönder (tüm step'leri tek migration dosyasına birleştir)

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/20260529000001_tanimlar_crud.sql
git commit -m "feat(db): Tanımlar paneli — stok_kategorileri tablo + 10 CRUD RPC + seed data"
```

---

### Task 2: IDB Sync — stok_kategorileri

**Files:**
- Modify: `js/api.js` (~line 10, ~line 305)

- [ ] **Step 1: TABLES dizisine stok_kategorileri ekle**

`js/api.js` satır 10-12:
```js
// Mevcut:
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler','treatment_days'];

// Yeni (sonuna stok_kategorileri ekle):
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler','treatment_days','stok_kategorileri'];
```

- [ ] **Step 2: FETCHERS'a stok_kategorileri ekle**

`js/api.js` satır ~328 (gebelik_ozet satırının altına):

```js
// Mevcut:
      gebelik_ozet:     () => db.from('gebelik_ozet_view').select('*'),

// Sonuna ekle:
      gebelik_ozet:     () => db.from('gebelik_ozet_view').select('*'),
      stok_kategorileri:() => db.from('stok_kategorileri').select('*').order('sira'),
```

- [ ] **Step 3: DB_VER bump**

`js/api.js` satır 9:
```js
// Mevcut:
const DB_VER  = 19;
// Yeni:
const DB_VER  = 20;
```

- [ ] **Step 4: Commit**

```bash
git add js/api.js
git commit -m "feat(api): stok_kategorileri IDB sync — TABLES + FETCHERS + DB_VER=20"
```

---

### Task 3: Global state + HTML panel

**Files:**
- Modify: `js/app.js` (~line 57)
- Modify: `index.html` (~line 492, ~line 557)

- [ ] **Step 1: Global state ekle**

`js/app.js` satır 57'de `_gecmisTumu` satırının altına:

```js
let _tanimlarTab = 'hastaliklar';
```

- [ ] **Step 2: Dashboard'a Tanımlar butonu ekle**

`index.html` satır 492 (`<div id="stok-list-body"...` satırının hemen üstüne):

```html
      <div data-action="open-tanimlar-panel" class="log-btn" style="margin-top:2px">
        <div class="log-ico" style="background:rgba(42,107,181,.12)">📋</div>
        <div class="log-text"><div class="log-title">Tanımlar</div><div class="log-sub">Hastalık, ilaç, kategori yönetimi</div></div>
        <svg class="log-arr" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg>
      </div>
```

- [ ] **Step 3: Slide-in panel HTML ekle**

`index.html` stok paneli kapanışından sonra (`</div>` satır 557) hemen altına:

```html
<div id="tanimlar-panel" style="position:fixed;inset:0;z-index:50;background:var(--card);display:flex;flex-direction:column;transform:translateX(100%);transition:transform .3s cubic-bezier(.32,0,.67,0)">
  <div style="background:var(--bg);padding:16px 16px 12px;padding-top:max(16px,env(safe-area-inset-top,16px));flex-shrink:0">
    <button data-action="close-tanimlar-panel" style="display:flex;align-items:center;gap:6px;color:var(--green3);font-size:.88rem;font-weight:700;background:none;border:none;cursor:pointer;margin-bottom:14px;text-transform:uppercase;letter-spacing:.06em;padding:10px 16px 10px 4px;min-height:44px">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/></svg>
      Kayda Dön
    </button>
    <div style="font-size:1.4rem;font-weight:800;color:#fff">📋 Tanımlar</div>
    <div style="font-size:.72rem;color:var(--ink3);margin-top:4px">Hastalık, ilaç ve kategori yönetimi</div>
  </div>
  <div id="tanimlar-tabs" style="display:flex;gap:4px;padding:8px 12px;overflow-x:auto;-webkit-overflow-scrolling:touch;flex-shrink:0;background:var(--bg)">
    <button class="kat-btn on" data-action="tanimlar-tab-hastaliklar">🏥 Hastalıklar</button>
    <button class="kat-btn" data-action="tanimlar-tab-ilaclar">💊 İlaçlar</button>
    <button class="kat-btn" data-action="tanimlar-tab-kategoriler">📂 Kategoriler</button>
  </div>
  <div style="flex:1;overflow-y:auto;-webkit-overflow-scrolling:touch;padding:12px 14px 80px">
    <div id="tanimlar-panel-body"><div class="loader"><div class="spin"></div></div></div>
  </div>
</div>
```

- [ ] **Step 4: Commit**

```bash
git add js/app.js index.html
git commit -m "feat(ui): Tanımlar paneli HTML shell + dashboard butonu + global state"
```

---

### Task 4: Panel render — Hastalıklar sekmesi

**Files:**
- Modify: `js/ui.js` (~line 2140 sonrası, closeStokPanel fonksiyonundan sonra)

- [ ] **Step 1: openTanimlarPanel + closeTanimlarPanel + setTanimlarTab fonksiyonları**

`js/ui.js`'te `closeStokPanel` fonksiyonundan sonra ekle:

```js
/* ═══ TANIMLAR PANELİ ═══ */
function openTanimlarPanel(){
  document.getElementById('tanimlar-panel').style.transform='translateX(0)';
  loadTanimlarPanel();
}
function closeTanimlarPanel(){
  document.getElementById('tanimlar-panel').style.transform='translateX(100%)';
}
function setTanimlarTab(tab,e){
  _tanimlarTab=tab;
  document.querySelectorAll('#tanimlar-tabs .kat-btn').forEach(b=>b.classList.remove('on'));
  if(e&&e.target) e.target.classList.add('on');
  loadTanimlarPanel();
}
```

- [ ] **Step 2: loadTanimlarPanel dispatcher**

```js
async function loadTanimlarPanel(){
  const el=document.getElementById('tanimlar-panel-body'); if(!el) return;
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  if(_tanimlarTab==='hastaliklar') await _renderHastaliklar(el);
  else if(_tanimlarTab==='ilaclar') await _renderIlaclar(el);
  else if(_tanimlarTab==='kategoriler') await _renderKategoriler(el);
}
```

- [ ] **Step 3: _renderHastaliklar fonksiyonu**

```js
async function _renderHastaliklar(el){
  await pullTables(['diseases','cases']);
  const diseases=await idbGetAll('diseases');
  const cases=await idbGetAll('cases');
  if(!diseases.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">🏥</div>Henüz hastalık tanımı yok</div>'+_tanimVarsayilanBtn('diseases');
    return;
  }
  const KAT_RENK={Meme:'#e91e63',Üreme:'#9c27b0',Metabolik:'#ff9800',Ayak:'#795548',Solunum:'#2196f3',Sindirim:'#4caf50',Buzağı:'#00bcd4',Diğer:'#607d8b'};
  let html=diseases.map(d=>{
    const aktif=cases.filter(c=>c.disease_id===d.id&&c.status==='active').length;
    const kapali=cases.filter(c=>c.disease_id===d.id&&c.status==='closed').length;
    const toplam=aktif+kapali;
    const renk=KAT_RENK[d.category]||'#607d8b';
    return `<div class="tanimlar-card" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${renk};border-radius:10px;padding:11px 13px;margin-bottom:7px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(d.name)}</div>
          <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">
            <span style="background:${renk}22;color:${renk};padding:1px 6px;border-radius:4px;font-weight:700">${d.category||'—'}</span>
            ${toplam?' · '+toplam+' vaka'+(aktif?' ('+aktif+' aktif)':''):''}
          </div>
        </div>
        <button onclick="_tanimEditForm('disease','${d.id}')" style="padding:6px 10px;background:var(--card2);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer;color:var(--ink3)">Düzenle</button>
      </div>
      <div id="tdf-disease-${d.id}"></div>
    </div>`;
  }).join('');
  html+=`<button onclick="_tanimEditForm('disease','new')" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni Hastalık Ekle</button>`;
  html+=_tanimVarsayilanBtn('diseases');
  el.innerHTML=html;
}

function _tanimVarsayilanBtn(tip){
  return `<div style="text-align:center;margin-top:14px">
    <button onclick="_tanimVarsayilan('${tip}')" style="background:none;border:none;color:var(--ink3);font-size:.72rem;cursor:pointer;text-decoration:underline">🔄 Varsayılana Dön</button>
  </div>`;
}
```

- [ ] **Step 4: _tanimEditForm — disease form**

```js
function _tanimEditForm(tip, id){
  document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove());
  if(tip==='disease') _diseaseEditForm(id);
  else if(tip==='drug') _drugEditForm(id);
  else if(tip==='kategori') _kategoriEditForm(id);
}

async function _diseaseEditForm(id){
  const isNew=id==='new';
  let name='',category='';
  if(!isNew){
    const all=await idbGetAll('diseases');
    const d=all.find(x=>x.id===id);
    if(d){name=d.name;category=d.category||'';}
  }
  const KATS=['Meme','Üreme','Metabolik','Ayak','Solunum','Sindirim','Buzağı','Diğer'];
  const katOpts=KATS.map(k=>`<option ${k===category?'selected':''} value="${k}">${k}</option>`).join('');
  const formHtml=`<div class="tanim-edit-form" style="background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:10px;margin-top:6px">
    <div style="margin-bottom:6px"><input id="tef-disease-name" class="fi" value="${esc(name)}" placeholder="Hastalık adı" style="margin:0"></div>
    <div style="margin-bottom:8px"><select id="tef-disease-cat" class="fsel" style="margin:0"><option value="">Kategori seç…</option>${katOpts}</select></div>
    <div style="display:flex;gap:6px">
      <button onclick="_diseaseSave('${id}')" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px;font-weight:700;cursor:pointer">${isNew?'Ekle':'Kaydet'}</button>
      ${isNew?'':`<button onclick="_diseaseDelete('${id}')" style="padding:8px 12px;background:#ffebee;color:#c62828;border:none;border-radius:7px;font-weight:700;cursor:pointer">Sil</button>`}
      <button onclick="document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove())" style="padding:8px 12px;background:var(--card3);border:none;border-radius:7px;cursor:pointer">İptal</button>
    </div>
  </div>`;
  if(isNew){
    const btn=document.querySelector('#tanimlar-panel-body button[onclick*="disease"][onclick*="new"]');
    if(btn) btn.insertAdjacentHTML('beforebegin',formHtml);
  } else {
    const wrap=document.getElementById('tdf-disease-'+id);
    if(wrap) wrap.innerHTML=formHtml;
  }
}
```

- [ ] **Step 5: _diseaseSave + _diseaseDelete**

```js
async function _diseaseSave(id){
  const name=document.getElementById('tef-disease-name')?.value.trim();
  const cat=document.getElementById('tef-disease-cat')?.value;
  if(!name){toast('Hastalık adı zorunlu','warn');return;}
  if(!cat){toast('Kategori seçin','warn');return;}
  const isNew=id==='new';
  const res=await rpcOptimistic(isNew?'disease_ekle':'disease_guncelle',
    isNew?{p_name:name,p_category:cat}:{p_id:id,p_name:name,p_category:cat},
    null,['diseases']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  loadTanimlarPanel();
}

async function _diseaseDelete(id){
  if(!confirm('Bu hastalığı silmek istediğinize emin misiniz?')) return;
  const res=await rpcOptimistic('disease_sil',{p_id:id},null,['diseases']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Hastalık silindi');
  loadTanimlarPanel();
}
```

- [ ] **Step 6: _tanimVarsayilan**

```js
async function _tanimVarsayilan(tip){
  const labels={diseases:'hastalık',drugs:'ilaç',kategoriler:'kategori'};
  if(!confirm(`Standart ${labels[tip]||tip} tanımları geri yüklenecek. Mevcut özel tanımlarınız silinmez. Devam?`)) return;
  const res=await rpcOptimistic('seed_defaults',{p_tip:tip},null,
    tip==='diseases'?['diseases']:tip==='drugs'?['drugs']:['stok_kategorileri']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast(`${res.eklenen||0} yeni ${labels[tip]} eklendi`);
  loadTanimlarPanel();
}
```

- [ ] **Step 7: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): Tanımlar paneli — hastalıklar sekmesi render + CRUD + varsayılana dön"
```

---

### Task 5: Panel render — İlaçlar sekmesi

**Files:**
- Modify: `js/ui.js` (aynı bölüm, `_renderHastaliklar` sonrası)

- [ ] **Step 1: _renderIlaclar fonksiyonu**

```js
async function _renderIlaclar(el){
  await pullTables(['drugs','stok']);
  const drugs=await idbGetAll('drugs');
  const stok=getState('stock');
  if(!drugs.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">💊</div>Henüz ilaç tanımı yok</div>'+_tanimVarsayilanBtn('drugs');
    return;
  }
  const YOL_RENK={IM:'#2196f3',IV:'#e91e63',SC:'#ff9800',PO:'#4caf50',Topikal:'#9c27b0',Intrauterin:'#795548'};
  let html=drugs.map(d=>{
    const s=d.stock_item_id?stok.find(x=>x.id===d.stock_item_id):null;
    const yolRenk=YOL_RENK[d.default_route]||'#607d8b';
    const stokInfo=s
      ?`<span style="color:var(--green);font-size:.65rem;font-weight:700">📦 ${esc(s.urun_adi)} (${(s.guncel||0).toFixed(s.birim==='adet'?0:1)} ${s.birim||''})</span>`
      :`<span style="color:var(--ink3);font-size:.65rem">⚠️ Stok bağlantısı yok</span>`;
    return `<div class="tanimlar-card" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${yolRenk};border-radius:10px;padding:11px 13px;margin-bottom:7px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(d.name)}</div>
          <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">
            ${d.default_route?`<span style="background:${yolRenk}22;color:${yolRenk};padding:1px 6px;border-radius:4px;font-weight:700">${d.default_route}</span>`:''} 
            ${d.default_unit?' · '+d.default_unit:''}
          </div>
          <div style="margin-top:3px">${stokInfo}</div>
        </div>
        <button onclick="_tanimEditForm('drug','${d.id}')" style="padding:6px 10px;background:var(--card2);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer;color:var(--ink3)">Düzenle</button>
      </div>
      <div id="tdf-drug-${d.id}"></div>
    </div>`;
  }).join('');
  html+=`<button onclick="_tanimEditForm('drug','new')" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni İlaç Ekle</button>`;
  html+=_tanimVarsayilanBtn('drugs');
  el.innerHTML=html;
}
```

- [ ] **Step 2: _drugEditForm fonksiyonu**

```js
async function _drugEditForm(id){
  const isNew=id==='new';
  let name='',unit='',route='',stockId='';
  if(!isNew){
    const all=await idbGetAll('drugs');
    const d=all.find(x=>x.id===id);
    if(d){name=d.name;unit=d.default_unit||'';route=d.default_route||'';stockId=d.stock_item_id||'';}
  }
  const BIRIMLER=['ml','mg','cc','adet'];
  const YOLLAR=['IM','IV','SC','PO','Topikal','Intrauterin'];
  const birimOpts=BIRIMLER.map(b=>`<option ${b===unit?'selected':''} value="${b}">${b}</option>`).join('');
  const yolOpts=YOLLAR.map(y=>`<option ${y===route?'selected':''} value="${y}">${y}</option>`).join('');

  const stok=getState('stock');
  const drugs=await idbGetAll('drugs');
  const usedIds=drugs.filter(d=>d.stock_item_id&&d.id!==id).map(d=>d.stock_item_id);
  const freeStok=stok.filter(s=>!usedIds.includes(s.id));
  const stokOpts=freeStok.map(s=>`<option ${s.id===stockId?'selected':''} value="${s.id}">${esc(s.urun_adi)} (${s.kategori})</option>`).join('');

  const formHtml=`<div class="tanim-edit-form" style="background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:10px;margin-top:6px">
    <div style="margin-bottom:6px"><input id="tef-drug-name" class="fi" value="${esc(name)}" placeholder="İlaç adı" style="margin:0"></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:6px">
      <select id="tef-drug-unit" class="fsel" style="margin:0"><option value="">Birim…</option>${birimOpts}</select>
      <select id="tef-drug-route" class="fsel" style="margin:0"><option value="">Uygulama yolu…</option>${yolOpts}</select>
    </div>
    <div style="margin-bottom:8px"><select id="tef-drug-stok" class="fsel" style="margin:0"><option value="">Stok bağlantısı (opsiyonel)</option>${stokOpts}</select></div>
    <div style="display:flex;gap:6px">
      <button onclick="_drugSave('${id}')" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px;font-weight:700;cursor:pointer">${isNew?'Ekle':'Kaydet'}</button>
      ${isNew?'':`<button onclick="_drugDelete('${id}')" style="padding:8px 12px;background:#ffebee;color:#c62828;border:none;border-radius:7px;font-weight:700;cursor:pointer">Sil</button>`}
      <button onclick="document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove())" style="padding:8px 12px;background:var(--card3);border:none;border-radius:7px;cursor:pointer">İptal</button>
    </div>
  </div>`;
  if(isNew){
    const btn=document.querySelector('#tanimlar-panel-body button[onclick*="drug"][onclick*="new"]');
    if(btn) btn.insertAdjacentHTML('beforebegin',formHtml);
  } else {
    const wrap=document.getElementById('tdf-drug-'+id);
    if(wrap) wrap.innerHTML=formHtml;
  }
}
```

- [ ] **Step 3: _drugSave + _drugDelete**

```js
async function _drugSave(id){
  const name=document.getElementById('tef-drug-name')?.value.trim();
  const unit=document.getElementById('tef-drug-unit')?.value||null;
  const route=document.getElementById('tef-drug-route')?.value||null;
  const stokId=document.getElementById('tef-drug-stok')?.value||null;
  if(!name){toast('İlaç adı zorunlu','warn');return;}
  const isNew=id==='new';
  const res=await rpcOptimistic(isNew?'drug_ekle':'drug_guncelle',
    isNew?{p_name:name,p_default_unit:unit,p_default_route:route,p_stock_item_id:stokId}
         :{p_id:id,p_name:name,p_default_unit:unit,p_default_route:route,p_stock_item_id:stokId},
    null,['drugs']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  loadTanimlarPanel();
}

async function _drugDelete(id){
  if(!confirm('Bu ilacı silmek istediğinize emin misiniz?')) return;
  const res=await rpcOptimistic('drug_sil',{p_id:id},null,['drugs']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('İlaç silindi');
  loadTanimlarPanel();
}
```

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): Tanımlar paneli — ilaçlar sekmesi render + CRUD"
```

---

### Task 6: Panel render — Kategoriler sekmesi

**Files:**
- Modify: `js/ui.js` (aynı bölüm)

- [ ] **Step 1: _renderKategoriler fonksiyonu**

```js
async function _renderKategoriler(el){
  await pullTables(['stok_kategorileri','stok']);
  const kats=await idbGetAll('stok_kategorileri');
  const stok=getState('stock');
  if(!kats.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">📂</div>Henüz kategori tanımı yok</div>'+_tanimVarsayilanBtn('kategoriler');
    return;
  }
  const sorted=[...kats].sort((a,b)=>(a.sira||0)-(b.sira||0));
  let html=sorted.map(k=>{
    const count=stok.filter(s=>s.kategori===k.ad).length;
    return `<div class="tanimlar-card" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid var(--blue);border-radius:10px;padding:11px 13px;margin-bottom:7px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(k.ad)}</div>
          <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">${count} ürün</div>
        </div>
        <button onclick="_tanimEditForm('kategori','${k.id}')" style="padding:6px 10px;background:var(--card2);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer;color:var(--ink3)">Düzenle</button>
      </div>
      <div id="tdf-kategori-${k.id}"></div>
    </div>`;
  }).join('');
  html+=`<button onclick="_tanimEditForm('kategori','new')" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni Kategori Ekle</button>`;
  html+=_tanimVarsayilanBtn('kategoriler');
  el.innerHTML=html;
}
```

- [ ] **Step 2: _kategoriEditForm fonksiyonu**

```js
async function _kategoriEditForm(id){
  const isNew=id==='new';
  let ad='';
  if(!isNew){
    const all=await idbGetAll('stok_kategorileri');
    const k=all.find(x=>x.id===id);
    if(k) ad=k.ad;
  }
  const formHtml=`<div class="tanim-edit-form" style="background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:10px;margin-top:6px">
    <div style="margin-bottom:8px"><input id="tef-kat-ad" class="fi" value="${esc(ad)}" placeholder="Kategori adı" style="margin:0"></div>
    <div style="display:flex;gap:6px">
      <button onclick="_kategoriSave('${id}')" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px;font-weight:700;cursor:pointer">${isNew?'Ekle':'Kaydet'}</button>
      ${isNew?'':`<button onclick="_kategoriDelete('${id}')" style="padding:8px 12px;background:#ffebee;color:#c62828;border:none;border-radius:7px;font-weight:700;cursor:pointer">Sil</button>`}
      <button onclick="document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove())" style="padding:8px 12px;background:var(--card3);border:none;border-radius:7px;cursor:pointer">İptal</button>
    </div>
  </div>`;
  if(isNew){
    const btn=document.querySelector('#tanimlar-panel-body button[onclick*="kategori"][onclick*="new"]');
    if(btn) btn.insertAdjacentHTML('beforebegin',formHtml);
  } else {
    const wrap=document.getElementById('tdf-kategori-'+id);
    if(wrap) wrap.innerHTML=formHtml;
  }
}
```

- [ ] **Step 3: _kategoriSave + _kategoriDelete**

```js
async function _kategoriSave(id){
  const ad=document.getElementById('tef-kat-ad')?.value.trim();
  if(!ad){toast('Kategori adı zorunlu','warn');return;}
  const isNew=id==='new';
  const res=await rpcOptimistic(isNew?'kategori_ekle':'kategori_guncelle',
    isNew?{p_ad:ad}:{p_id:id,p_new_ad:ad},
    null,['stok_kategorileri','stok']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  loadTanimlarPanel();
}

async function _kategoriDelete(id){
  if(!confirm('Bu kategoriyi silmek istediğinize emin misiniz?')) return;
  const res=await rpcOptimistic('kategori_sil',{p_id:id},null,['stok_kategorileri']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Kategori silindi');
  loadTanimlarPanel();
}
```

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): Tanımlar paneli — kategoriler sekmesi render + CRUD"
```

---

### Task 7: Action handler'lar

**Files:**
- Modify: `js/utils/handlers.js` (~line 95)

- [ ] **Step 1: Panel open/close handler'ları ekle**

`js/utils/handlers.js`'te `'open-stok-panel'` satırının altına ekle:

```js
  'open-tanimlar-panel':  () => openTanimlarPanel(),
```

`'close-stok-panel'` satırının altına ekle:

```js
  'close-tanimlar-panel': () => closeTanimlarPanel(),
```

- [ ] **Step 2: Sekme handler'ları ekle**

Stok tab handler'larının bulunduğu bölüme (handlers.js'te `stok-tab-*` action'ları arayın) altına ekle:

```js
  'tanimlar-tab-hastaliklar': (el) => setTanimlarTab('hastaliklar', {target:el}),
  'tanimlar-tab-ilaclar':     (el) => setTanimlarTab('ilaclar', {target:el}),
  'tanimlar-tab-kategoriler':  (el) => setTanimlarTab('kategoriler', {target:el}),
```

- [ ] **Step 3: Commit**

```bash
git add js/utils/handlers.js
git commit -m "feat(handlers): Tanımlar paneli action handler'ları"
```

---

### Task 8: ground_truth güncelle + global comment fix

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`
- Modify: `js/ui.js` (global comment)
- Modify: `js/app.js` (global comment)

- [ ] **Step 1: ground_truth'a stok_kategorileri tablosu + RPC'leri ekle**

`99999999999999_ground_truth.sql` dosyasının uygun bölümüne Task 1'deki tüm SQL'i ekle (diseases bölümünden önce stok_kategorileri tablosu, RPC bölümüne 10 RPC + seed_defaults).

- [ ] **Step 2: ui.js global comment'e yeni fonksiyonları ekle**

Dosyanın başındaki `/* global ... */` comment'ine ekle:
```
openTanimlarPanel, closeTanimlarPanel, setTanimlarTab, loadTanimlarPanel,
_renderHastaliklar, _renderIlaclar, _renderKategoriler,
_tanimEditForm, _diseaseEditForm, _drugEditForm, _kategoriEditForm,
_diseaseSave, _diseaseDelete, _drugSave, _drugDelete, _kategoriSave, _kategoriDelete,
_tanimVarsayilan, _tanimVarsayilanBtn, _tanimlarTab
```

- [ ] **Step 3: app.js global comment'e _tanimlarTab ekle**

`_gecmisTumu` varsa onun yanına `_tanimlarTab` ekle.

- [ ] **Step 4: Commit + Push**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql js/ui.js js/app.js
git commit -m "docs(db): ground_truth + global comment — Tanımlar paneli fonksiyonları"
git push origin main
```

---

## Doğrulama Kontrol Listesi

- [ ] Dashboard'da "Tanımlar" butonu görünüyor, tıklayınca panel açılıyor
- [ ] Hastalıklar sekmesinde mevcut hastalıklar listeleniyor (vaka sayısı ile)
- [ ] Yeni hastalık ekleme çalışıyor (duplicate kontrolü)
- [ ] Hastalık düzenleme çalışıyor
- [ ] Vaka olan hastalık silmeye çalışınca detaylı hata mesajı
- [ ] İlaçlar sekmesinde mevcut ilaçlar listeleniyor (stok bağlantısı ile)
- [ ] Yeni ilaç ekleme + stok bağlantısı çalışıyor
- [ ] İlaç düzenleme çalışıyor
- [ ] Tedavide kullanılmış ilaç silmeye çalışınca hata mesajı
- [ ] Kategoriler sekmesinde tüm stok kategorileri listeleniyor
- [ ] Yeni kategori ekleme çalışıyor
- [ ] Kategori ad değişince bağlı stok ürünleri de güncelleniyor
- [ ] Ürünü olan kategori silinemiyor
- [ ] Her sekmede "Varsayılana Dön" çalışıyor (eksik olanları ekliyor)
- [ ] Panel kapatılıp açılınca state korunuyor
