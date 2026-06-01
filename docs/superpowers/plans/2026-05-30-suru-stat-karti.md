# Sürü İstatistik Kartı — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sürü sekmesindeki `#padok-ozet` chip'lerini accordion stat kartına dönüştürmek — hayvan demografisi + gebelik istatistikleri, padok filtresiyle dinamik.

**Architecture:** Tek RPC (`stat_suru_ozet`) tüm verileri döndürür. UI fire-and-forget çağrı yapar, `loadAnimals` ile paralel, padok bazlı cache. Üreme sekmesindeki eski stat kartı kaldırılır.

**Tech Stack:** PostgreSQL plpgsql, vanilla JS, Supabase JS client

---

## File Map

| Dosya | Değişiklik | Sorumluluk |
|-------|-----------|------------|
| `supabase/migrations/20260530200000_stat_suru_ozet.sql` | CREATE | Yeni RPC |
| `supabase/migrations/99999999999999_ground_truth.sql` | MODIFY | RPC'yi ground truth'a ekle |
| `index.html` | MODIFY | `#padok-ozet` → `#suru-stat-card`, `#ureme-stat-card` kaldır |
| `js/ui.js` | MODIFY | Yeni render fonksiyonları, eski üreme stat kaldır, `updatePadokOzet` kaldır |
| `js/api.js` | MODIFY | Cache invalidation `_suruStatCache={}` |

---

### Task 1: Migration — `stat_suru_ozet` RPC

**Files:**
- Create: `supabase/migrations/20260530200000_stat_suru_ozet.sql`

- [ ] **Step 1: RPC dosyasını oluştur**

```sql
-- Sürü istatistik RPC — hayvan demografisi + gebelik istatistikleri
CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan jsonb;
  v_gebelik jsonb;
BEGIN
  -- ── CTE 1: Hayvan demografisi ──
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE
                grup ILIKE '%inek%' OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%'
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
                 AND (p_padok IS NULL OR h2.padok = p_padok))
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif'
    AND (p_padok IS NULL OR h.padok = p_padok);

  -- ── CTE 2: Gebelik istatistikleri ──
  WITH tohum AS (
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
      AND h.durum = 'Aktif'
      AND (p_padok IS NULL OR h.padok = p_padok)
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
        FROM tohum GROUP BY kategori
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
        FROM tohum
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
          'no', deneme_no,
          'gebe', COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran', ROUND(
                    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM tohum
        WHERE deneme_no IS NOT NULL
        GROUP BY deneme_no
      ) sub
    )
  ) INTO v_gebelik
  FROM tohum;

  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0}'::jsonb),
    'gebelik', COALESCE(v_gebelik, '{"ozet":{"toplam":0,"gebe":0,"bos":0,"abort":0,"bekleyen":0,"oran":null},"kategori":[],"sperma_top5":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet TO anon, authenticated;
```

- [ ] **Step 2: Migration'ı Supabase'e uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push`
Expected: Migration başarılı, `stat_suru_ozet` fonksiyonu oluşur.

Alternatif (management API):
```
supabase_migrate({sql: "<yukarıdaki SQL>"})
```

- [ ] **Step 3: RPC'yi test et**

```
supabase_rpc({function_name: "stat_suru_ozet", params: "{}"})
```
Expected: `hayvan` ve `gebelik` key'leri olan jsonb döner.

Padok filtreli test:
```
supabase_rpc({function_name: "stat_suru_ozet", params: "{\"p_padok\":\"Sağmal Padok\"}"})
```
Expected: Sadece Sağmal Padok hayvanlarının istatistikleri.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260530200000_stat_suru_ozet.sql
git commit -m "feat(stat): stat_suru_ozet RPC — hayvan demografisi + gebelik istatistikleri"
```

---

### Task 2: Ground Truth Güncelleme

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

- [ ] **Step 1: Ground truth'a RPC'yi ekle**

`99999999999999_ground_truth.sql` dosyasının sonuna (son `GRANT` satırlarından önce, uygun yere) Task 1'deki `CREATE OR REPLACE FUNCTION public.stat_suru_ozet(...)` bloğunun tamamını ekle. `GRANT` satırı dahil.

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "docs(db): ground_truth — stat_suru_ozet RPC eklendi"
```

---

### Task 3: HTML — `#padok-ozet` → `#suru-stat-card`, üreme stat kaldır

**Files:**
- Modify: `index.html:383` — padok-ozet div
- Modify: `index.html:410` — ureme-stat-card div

- [ ] **Step 1: `#padok-ozet` div'ini `#suru-stat-card`'a dönüştür**

`index.html:383` satırını değiştir:

```html
<!-- ESKİ -->
<div id="padok-ozet" style="display:flex;gap:6px;flex-wrap:wrap;padding:4px 0 2px"></div>

<!-- YENİ -->
<div id="suru-stat-card"></div>
```

- [ ] **Step 2: `#ureme-stat-card` div'ini kaldır**

`index.html:410` satırını sil:

```html
<!-- SİL -->
<div id="ureme-stat-card"></div>
```

- [ ] **Step 3: CSS — `.stat-row` class çakışmasını düzelt**

`index.html:85` satırında dashboard `.stat-row` (grid layout) ile `index.html:162` satırındaki accordion `.stat-row` (font-size + padding) çakışıyor. Dashboard'daki class adını `.dash-row` olarak değiştir:

`index.html:85` satırını değiştir:
```css
/* ESKİ */
.stat-row{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin-bottom:10px}

/* YENİ */
.dash-row{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin-bottom:10px}
```

Dashboard JS'te class kullanımını güncelle — `js/ui.js:99` satırında:
```js
// ESKİ
return `<div class="stat-row">

// YENİ
return `<div class="dash-row">
```

- [ ] **Step 4: CSS — mini loading spinner ekle**

Mevcut `.stat-arrow` satırından sonra (`index.html:155` civarı) ekle:

```css
.stat-loading{display:inline-block;width:12px;height:12px;border:2px solid var(--ink3);border-top-color:transparent;border-radius:50%;animation:spin .6s linear infinite;margin-left:6px;vertical-align:middle}
```

Not: `spin` animasyonu zaten mevcut (`.spin` class'ı için tanımlı).

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(ui): suru-stat-card div + üreme stat card kaldır + CSS düzelt"
```

---

### Task 4: JS — Eski stat kodunu kaldır, yeni render fonksiyonları yaz

**Files:**
- Modify: `js/ui.js:662-681` — `updatePadokOzet` kaldır
- Modify: `js/ui.js:1736-1778` — üreme stat fonksiyonları kaldır
- Modify: `js/ui.js:641,660` — `updatePadokOzet` çağrılarını kaldır
- Modify: `js/ui.js:1782` — `_renderUremeStat()` çağrısını kaldır
- Modify: `js/api.js:304` — cache invalidation güncelle

- [ ] **Step 1: `updatePadokOzet` fonksiyonunu kaldır**

`js/ui.js:662-681` satırlarını sil (fonksiyon tanımı).

`js/ui.js:641` satırında `updatePadokOzet(list)` çağrısını sil:
```js
// ESKİ
if(!list.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Hayvan bulunamadı</div>'; updatePadokOzet(list); return; }

// YENİ
if(!list.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Hayvan bulunamadı</div>'; return; }
```

`js/ui.js:660` satırında `updatePadokOzet(list)` çağrısını sil.

- [ ] **Step 2: Üreme stat fonksiyonlarını kaldır**

`js/ui.js:1736-1778` satırlarını sil:
- `_uremStatCache` değişkeni
- `_uremStatOpen` değişkeni
- `_renderUremeStat()` fonksiyonu
- `_applyStatHtml()` fonksiyonu
- `_toggleUremeStat()` fonksiyonu

`js/ui.js:1782` satırında `_renderUremeStat();` çağrısını sil (`loadUreme` fonksiyonunun içinden).

- [ ] **Step 3: Cache invalidation güncelle**

`js/api.js:304` satırını değiştir:
```js
// ESKİ
_uremStatCache=null;

// YENİ
_suruStatCache={};
```

- [ ] **Step 4: Yeni sürü stat fonksiyonlarını yaz**

`js/ui.js`'de, silinen `updatePadokOzet` fonksiyonunun yerine (satır 662 civarı) şu kodu ekle:

```js
// ── SÜRÜ STAT KARTI ─────────────────────────
let _suruStatCache={};
let _suruStatOpen=false;
let _suruDenemeOpen=false;

function _renderSuruStat(){
  const el=document.getElementById('suru-stat-card'); if(!el) return;
  const padok=document.getElementById('pflt')?.value||'';
  const key=padok;
  if(_suruStatCache[key]){
    _applySuruStatHtml(el,_suruStatCache[key],padok);
    _fetchSuruStat(el,padok,key);
    return;
  }
  // İlk yükleme — eski veri yoksa loading göster
  if(el.innerHTML){
    _showStatLoading(el,true);
  }
  _fetchSuruStat(el,padok,key);
}

function _fetchSuruStat(el,padok,key){
  const params=padok?{p_padok:padok}:{};
  db.rpc('stat_suru_ozet',params).then(({data})=>{
    if(data){
      _suruStatCache[key]=data;
      _applySuruStatHtml(el,data,padok);
    }
  }).catch(e=>console.warn('stat_suru_ozet:',e.message));
}

function _showStatLoading(el,show){
  const sp=el.querySelector('.stat-loading');
  if(show&&!sp){
    const h=el.querySelector('.stat-header');
    if(h){const s=document.createElement('span');s.className='stat-loading';h.appendChild(s);}
  } else if(!show&&sp){ sp.remove(); }
}

function _applySuruStatHtml(el,d,padok){
  const h=d.hayvan||{};
  const g=(d.gebelik||{}).ozet||{};
  const oran=g.oran!=null?`%${g.oran}`:'—';
  const padokLabel=padok?`🏠 ${esc(padok)} — `:'';

  // Demografik bölüm
  const demoHtml=`<div class="stat-section">
    <div class="stat-section-title">📋 Demografik</div>
    <div class="stat-row">🐄 İnek: ${h.inek||0} · 🐮 Düve: ${h.duve||0} · 🐂 Erkek: ${h.erkek||0} · 🍼 Buzağı: ${h.buzagi||0} · 💲 Kısır: ${h.kisir||0}</div>
  </div>`;

  // Gebelik bölümü
  const katHtml=(d.gebelik?.kategori||[]).map(k=>{
    const ico=k.ad==='İnek'?'🐄':k.ad==='Düve'?'🐮':'❓';
    return `${ico} ${esc(k.ad)}: %${k.oran!=null?k.oran:'—'} (${k.toplam} tohum)`;
  }).join(' · ')||'Veri yok';

  const gebHtml=`<div class="stat-section">
    <div class="stat-section-title">🤰 Gebelik</div>
    <div class="stat-row">💉 ${g.toplam||0} tohumlama · ✅ ${g.gebe||0} gebe · ⭕ ${g.bos||0} boş · ⏳ ${g.bekleyen||0} bekleyen</div>
    <div class="stat-row">${katHtml}</div>
  </div>`;

  // Top spermalar
  const spHtml=(d.gebelik?.sperma_top5||[]).map(s=>
    `<div class="stat-row">${esc(s.ad)} — ${s.toplam} tohum → <b>%${s.oran!=null?s.oran:'—'}</b></div>`
  ).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const spSection=`<div class="stat-section"><div class="stat-section-title">🏆 Top Spermalar (≥3 tohum)</div>${spHtml}</div>`;

  // Deneme dağılımı — sub-accordion
  const deneme=d.gebelik?.deneme||[];
  const first3=deneme.filter(dn=>dn.no<=3);
  const rest=deneme.filter(dn=>dn.no>3);
  const dnFirst=first3.map(dn=>
    `<div class="stat-row">${dn.no}. deneme: ${dn.gebe} gebe / ${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const dnRest=rest.map(dn=>
    `<div class="stat-row">${dn.no}. deneme: ${dn.gebe} gebe / ${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const restBtn=rest.length>0?`<div id="deneme-rest" style="display:${_suruDenemeOpen?'block':'none'}">${dnRest}</div><div class="stat-row"><span onclick="_toggleDenemeRest()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">${_suruDenemeOpen?'Daralt':'[+'+rest.length+' daha]'}</span></div>`:'';
  const dnSection=`<div class="stat-section"><div class="stat-section-title">🔢 Deneme Dağılımı</div>${dnFirst}${restBtn}</div>`;

  el.innerHTML=`<div class="stat-card${_suruStatOpen?' open':''}" onclick="_toggleSuruStat(event)">
    <div class="stat-header"><span>${padokLabel}🐄 ${h.toplam||0} hayvan · 🤰 ${g.gebe||0} gebe (${oran}) · 🏥 ${h.hasta||0} hasta</span><span class="stat-arrow">▼</span></div>
    <div class="stat-detail">${demoHtml}${gebHtml}${spSection}${dnSection}</div>
  </div>`;
}

function _toggleSuruStat(e){
  if(e.target.closest('#deneme-rest')||e.target.onclick) return;
  _suruStatOpen=!_suruStatOpen;
  const c=document.querySelector('#suru-stat-card .stat-card');
  if(c) c.classList.toggle('open',_suruStatOpen);
}

function _toggleDenemeRest(){
  _suruDenemeOpen=!_suruDenemeOpen;
  const rest=document.getElementById('deneme-rest');
  if(rest) rest.style.display=_suruDenemeOpen?'block':'none';
  // Re-render to update button text
  const padok=document.getElementById('pflt')?.value||'';
  const data=_suruStatCache[padok];
  if(data){
    const el=document.getElementById('suru-stat-card');
    if(el) _applySuruStatHtml(el,data,padok);
  }
}
```

- [ ] **Step 5: `_renderSuruStat` çağrılarını ekle**

`loadAnimals` fonksiyonuna (satır ~589, `renderAnimals(sorted)` satırından sonra) ekle:
```js
_renderSuruStat();
```

`filterA` fonksiyonuna (satır ~729, `setTimeout` callback'inin sonuna, `renderAnimals` çağrısından sonra) ekle:
```js
_renderSuruStat();
```

- [ ] **Step 6: Commit**

```bash
git add js/ui.js js/api.js
git commit -m "feat(stat): sürü stat kartı — demografik + gebelik, padok cache, deneme sub-accordion"
```

---

### Task 5: Ground Truth + Temizlik + Push

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

- [ ] **Step 1: Ground truth'un güncel olduğunu doğrula**

Task 2'de eklenen `stat_suru_ozet` RPC'nin ground truth'ta olduğunu kontrol et:
```bash
grep -c 'stat_suru_ozet' supabase/migrations/99999999999999_ground_truth.sql
```
Expected: 1 veya daha fazla match.

- [ ] **Step 2: Tarayıcıda test et**

1. Sürü sekmesine git → stat kartı kapalı halde yüklenmeli: `🐄 N hayvan · 🤰 N gebe (%X) · 🏥 N hasta`
2. Tıkla → accordion açılır: demografik + gebelik + spermalar + deneme dağılımı
3. Padok dropdown'dan "Sağmal Padok" seç → kart güncellenir, mini loading spinner gösterilir
4. Tekrar "Tüm Padoklar"a dön → cache'ten anında yüklenir
5. Deneme dağılımında `[+N daha]` butonuna tıkla → geri kalan denemeler açılır
6. `[Daralt]`'a tıkla → ilk 3'e döner

- [ ] **Step 3: Eski stat_gebelik_ozet kontrolü**

Üreme sekmesine git → `_renderUremeStat` kaldırıldı, eski stat kartı görünmemeli. Üreme sekmesinin normal fonksiyonları (kızgınlık, tohumlama, gebelik listeleri) çalışmalı.

- [ ] **Step 4: Commit + Push**

```bash
git add -A
git commit -m "feat(stat): sürü stat kartı tamamlandı — padok filtre + cache + deneme sub-accordion"
git push origin main
```
