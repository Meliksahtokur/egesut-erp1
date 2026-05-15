> **🟡 KISMEN TAMAMLANDI** — Commit: `d833be8` (gorev_geri_al RPC fix). Görev geri alma çalışıyor ancak rapel tarihi gösterme, done görev detayı, kategori filtresi henüz implemente edilmedi.

# Görev Sistemi İyileştirmeleri Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tamamlanan görevlerde rapel tarihi göster, done görev detay/geri alma ekle, kategori filtresi ekle.

**Architecture:** Tek dosya (js/ui.js) + 1 migration (gorev_geri_al RPC) + index.html modal güncellemesi. Frontend-ağırlıklı, mevcut pattern'ları takip eder.

**Tech Stack:** Vanilla JS, Supabase RPC (plpgsql), IndexedDB, PWA offline-first

---

### Task 1: Tamamlanan Görevlerde Rapel Tarihi + Tıklanabilirlik

**Files:**
- Modify: `js/ui.js:293-307` (loadTasks done branch)

- [ ] **Step 1: Done kart render'ını güncelle — rapel tarih + onclick**

`js/ui.js` içinde `loadTasks` fonksiyonundaki `if(f==='done')` bloğunu değiştir. Mevcut (line 293-307):

```js
    if(f==='done'){
      let done=all.filter(t=>t.tamamlandi&&!t.parent_id);
      done.sort((a,b)=>(b.tamamlanma_tarihi||b.hedef_tarih||'').localeCompare(a.tamamlanma_tarihi||a.hedef_tarih||''));
      if(!done.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Henüz tamamlanan görev yok</div>'; return; }
      el.innerHTML=done.slice(0,150).map(t=>`<div class="task-card" style="border-left-color:var(--ink3);opacity:.65">
        <div class="tc-header"><div class="tc-main">
          <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
            <span class="tc-id">${(()=>{const h=getState('animals').find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'GENEL');})()} </span>
            <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          </div>
          <div class="tc-desc">${t.aciklama||''}</div>
          <div class="tc-meta" style="color:var(--green)">✅ Tamamlandı: ${fmtTarih(t.tamamlanma_tarihi||t.hedef_tarih)}</div>
        </div></div>
      </div>`).join('');
      return;
    }
```

Yenisi:

```js
    if(f==='done'){
      let done=all.filter(t=>t.tamamlandi&&!t.parent_id);
      done.sort((a,b)=>(b.tamamlanma_tarihi||b.hedef_tarih||'').localeCompare(a.tamamlanma_tarihi||a.hedef_tarih||''));
      if(!done.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Henüz tamamlanan görev yok</div>'; return; }
      el.innerHTML=done.slice(0,150).map(t=>{
        const rapelChild=all.find(c=>c.parent_id===t.id&&!c.tamamlandi);
        const rapelStr=rapelChild?`<div style="font-size:.7rem;color:var(--blue);margin-top:2px">📅 Rapel: ${fmtTarih(rapelChild.hedef_tarih)}</div>`:'';
        return `<div class="task-card" style="border-left-color:var(--ink3);opacity:.75;cursor:pointer" onclick="openDoneTaskDet('${t.id}')">
        <div class="tc-header"><div class="tc-main">
          <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
            <span class="tc-id">${(()=>{const h=getState('animals').find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'GENEL');})()} </span>
            <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          </div>
          <div class="tc-desc">${t.aciklama||''}</div>
          <div class="tc-meta" style="color:var(--green)">✅ ${fmtTarih(t.tamamlanma_tarihi||t.hedef_tarih)}</div>
          ${rapelStr}
        </div></div>
      </div>`;
      }).join('');
      return;
    }
```

- [ ] **Step 2: Commit**

```bash
git add js/ui.js && git commit -m "feat: done kart rapel tarih gösterir + tıklanabilir"
```

---

### Task 2: Tamamlanmış Görev Detay Modal

**Files:**
- Modify: `index.html` (yeni modal ekle)
- Modify: `js/ui.js` (openDoneTaskDet fonksiyonu ekle)

- [ ] **Step 1: index.html'e done görev detay modal ekle**

`index.html`'de `m-task-det` modal'ının SONRASINA ekle (line ~955 civarı):

```html
<div id="m-done-det" class="mo" onclick="mClose(event,this)">
  <div class="modal"><div class="m-handle"></div><div class="m-title">✅ Tamamlanan Görev</div>
    <div class="m-body">
      <div id="dd-hayvan" style="font-size:1.1rem;font-weight:800;margin-bottom:6px"></div>
      <div id="dd-aciklama" style="font-size:.85rem;color:var(--ink);margin-bottom:10px"></div>
      <div id="dd-meta" style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:12px;font-size:.72rem"></div>
      <div id="dd-rapel" style="display:none;background:rgba(42,107,181,.08);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:10px;margin-bottom:12px;font-size:.8rem"></div>
      <div style="display:flex;gap:8px;margin-top:14px">
        <button id="dd-geri-al-btn" class="btn" style="flex:1;background:#fff3e0;color:#b84c00;border:1px solid #f0b060;font-weight:700" onclick="gorevGeriAl()">↩️ Geri Al</button>
        <button class="btn btn-o" style="flex:1" onclick="closeM('m-done-det')">Kapat</button>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: js/ui.js'e openDoneTaskDet fonksiyonu ekle**

`detayIptal()` fonksiyonunun SONRASINA ekle:

```js
async function openDoneTaskDet(id){
  const all=await idbGetAll('gorev_log');
  const t=all.find(x=>x.id===id); if(!t) return;
  _curTaskDet=t;
  const hayvan=getState('animals').find(a=>a.id===t.hayvan_id);
  document.getElementById('dd-hayvan').textContent=(hayvan?.kupe_no||hayvan?.devlet_kupe)||t.hayvan_id||'GENEL';
  document.getElementById('dd-aciklama').textContent=t.aciklama||'';
  const meta=[];
  meta.push(`📅 Hedef: ${fmtTarih(t.hedef_tarih)}`);
  meta.push(`✅ Tamamlandı: ${fmtTarih(t.tamamlanma_tarihi)}`);
  meta.push(`🏷 ${(t.gorev_tipi||'DIGER').replace(/_/g,' ')}`);
  document.getElementById('dd-meta').innerHTML=meta.map(m=>`<span style="background:var(--card2);padding:3px 8px;border-radius:10px">${m}</span>`).join('');
  const rapelEl=document.getElementById('dd-rapel');
  const rapelChild=all.find(c=>c.parent_id===id);
  if(rapelChild){
    rapelEl.style.display='block';
    rapelEl.innerHTML=rapelChild.tamamlandi
      ?`📅 Rapel: ${fmtTarih(rapelChild.hedef_tarih)} — <span style="color:var(--green)">✅ Yapıldı</span>`
      :`📅 Rapel: ${fmtTarih(rapelChild.hedef_tarih)} — <span style="color:var(--orange)">Bekliyor</span>`;
  } else { rapelEl.style.display='none'; }
  const geriBtn=document.getElementById('dd-geri-al-btn');
  const daysSince=Math.floor((Date.now()-new Date(t.tamamlanma_tarihi||0))/86400000);
  const childDone=rapelChild&&rapelChild.tamamlandi;
  if(daysSince>7||childDone){
    geriBtn.disabled=true;
    geriBtn.textContent=childDone?'Rapel yapılmış (geri alınamaz)':'7 günden eski';
  } else {
    geriBtn.disabled=false;
    geriBtn.textContent='↩️ Geri Al';
  }
  openM('m-done-det');
}
```

- [ ] **Step 3: openTaskDet'teki "zaten tamamlanmış" guard'ını kaldır**

`js/ui.js` line 1876'daki satırı değiştir:

Mevcut:
```js
  if(t.tamamlandi){ toast('Bu görev zaten tamamlanmış'); return; }
```

Yeni:
```js
  if(t.tamamlandi){ openDoneTaskDet(id); return; }
```

- [ ] **Step 4: Commit**

```bash
git add index.html js/ui.js && git commit -m "feat: tamamlanan görev detay modal — rapel bilgisi + geri al butonu"
```

---

### Task 3: Görev Geri Alma RPC (Backend)

**Files:**
- Create: `supabase/migrations/20260510000001_gorev_geri_al.sql`

- [ ] **Step 1: Migration dosyası oluştur**

```sql
-- Migration: gorev_geri_al RPC
-- Etkiler: Tamamlanan görevi geri al — vaccination + stok + child sil
-- Geri alınabilir: DROP FUNCTION public.gorev_geri_al(text);

BEGIN;

CREATE OR REPLACE FUNCTION public.gorev_geri_al(
  p_gorev_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_id      uuid;
  v_child_count integer;
BEGIN
  -- 1. Görevi çek
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF NOT v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten aktif');
  END IF;

  -- 2. 7 gün kontrolü
  IF v_gorev.tamamlanma_tarihi < now() - interval '7 days' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', '7 günden eski görevler geri alınamaz');
  END IF;

  -- 3. Child görev tamamlanmış mı?
  IF EXISTS (SELECT 1 FROM gorev_log WHERE parent_id = p_gorev_id::uuid AND tamamlandi = true) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Rapel görevi tamamlanmış, geri alınamaz');
  END IF;

  -- 4. vaccination_log'dan ilgili kaydı bul ve sil (GorevID notes'ta)
  SELECT id INTO v_vax_id FROM vaccination_log
  WHERE notes LIKE '%GorevID:' || p_gorev_id || '%'
  ORDER BY created_at DESC LIMIT 1;

  IF v_vax_id IS NOT NULL THEN
    -- stok hareketi geri al (vaccination_log silince trigger varsa o halleder, yoksa manuel)
    DELETE FROM stok_hareket WHERE kaynak = 'vaccination' AND kaynak_id = v_vax_id::text;
    DELETE FROM vaccination_log WHERE id = v_vax_id;
  END IF;

  -- 5. Child görevleri sil (rapel vs.)
  SELECT COUNT(*) INTO v_child_count FROM gorev_log WHERE parent_id = p_gorev_id::uuid;
  DELETE FROM gorev_log WHERE parent_id = p_gorev_id::uuid;

  -- 6. Görevi geri aç
  UPDATE gorev_log
  SET tamamlandi = false, tamamlanma_tarihi = null
  WHERE id = p_gorev_id::uuid;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_rapel', v_child_count,
    'silinen_asi_id', v_vax_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_geri_al(text) TO anon, authenticated;

END;
```

- [ ] **Step 2: Migration'ı Supabase'e uygula**

```bash
# MCP üzerinden veya doğrudan:
# supabase_migrate ile SQL'i çalıştır
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260510000001_gorev_geri_al.sql && git commit -m "feat: gorev_geri_al RPC — vaccination + stok + child temizle"
```

---

### Task 4: Geri Alma Frontend (gorevGeriAl fonksiyonu)

**Files:**
- Modify: `js/ui.js` (gorevGeriAl fonksiyonu ekle)

- [ ] **Step 1: gorevGeriAl fonksiyonunu ekle**

`openDoneTaskDet` fonksiyonunun SONRASINA ekle:

```js
function gorevGeriAl(){
  if(!_curTaskDet) return;
  const t=_curTaskDet;
  openConfirm('Görevi Geri Al','Bu işlem aşı kaydını ve rapel görevini silecektir. Stok miktarı düzeltilecektir.',async()=>{
    const btn=document.getElementById('dd-geri-al-btn');
    if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
    try{
      const res=await rpc('gorev_geri_al',{p_gorev_id:t.id});
      if(!res.ok){ toast(_trErr(res.mesaj||'Hata'),true); return; }
      closeM('m-done-det');
      await pullTables(['gorev_log','vaccination_log','stok_hareket']).catch(()=>{});
      updateTaskBadge();
      loadTasks(_curTaskFilter||'today');
      loadDash();
      toast(`↩️ Görev geri alındı${res.silinen_rapel?' · Rapel silindi':''}`);
    }catch(e){
      toast(_trErr(e.message),true);
    }finally{
      if(btn){btn.disabled=false;btn.textContent='↩️ Geri Al';}
    }
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add js/ui.js && git commit -m "feat: gorevGeriAl frontend — onay + RPC + UI refresh"
```

---

### Task 5: Görev Kategori Filtresi

**Files:**
- Modify: `index.html` (filter bar HTML)
- Modify: `js/ui.js` (filter state + loadTasks güncelle)

- [ ] **Step 1: index.html'e kategori filter bar ekle**

`index.html`'de görev sekmeleri ile tasks-body arasına (id="tasks-body" öncesine) ekle:

```html
<div id="task-kategori-bar" style="display:flex;gap:6px;padding:0 14px 10px;overflow-x:auto;-webkit-overflow-scrolling:touch">
  <button class="kat-btn on" onclick="setTaskKat('all',this)">Tümü</button>
  <button class="kat-btn" onclick="setTaskKat('asi',this)">💉 Aşı</button>
  <button class="kat-btn" onclick="setTaskKat('vitamin',this)">💊 Takviye</button>
  <button class="kat-btn" onclick="setTaskKat('kontrol',this)">🔍 Kontrol</button>
  <button class="kat-btn" onclick="setTaskKat('tedavi',this)">🩺 Tedavi</button>
  <button class="kat-btn" onclick="setTaskKat('bakim',this)">🐄 Bakım</button>
</div>
```

CSS'i `<style>` bloğuna ekle:
```css
.kat-btn{padding:5px 12px;border-radius:16px;border:1px solid var(--card3);background:var(--card);color:var(--ink3);font-size:.72rem;font-weight:700;white-space:nowrap;cursor:pointer}
.kat-btn.on{background:rgba(78,154,42,.15);border-color:var(--green);color:var(--green)}
```

- [ ] **Step 2: js/ui.js'e kategori state + filter logic ekle**

Dosyanın üstündeki state tanımlarına (line ~20 civarı, `_curTaskFilter` yanına):

```js
let _taskKategori='all';
const _katTipMap={
  asi:['ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE'],
  kontrol:['MUAYENE','GEBELIK_KONTROL','TARTIM'],
  tedavi:['TEDAVI','ILAC_UYGULAMA'],
  bakim:['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP']
};
function setTaskKat(kat,btn){
  _taskKategori=kat;
  document.querySelectorAll('.kat-btn').forEach(b=>b.classList.remove('on'));
  if(btn) btn.classList.add('on');
  loadTasks(_curTaskFilter||'today');
}
```

- [ ] **Step 3: loadTasks'ta kategori filtresini uygula**

`loadTasks` içinde, `data.sort(...)` satırından ÖNCE (line ~315 civarı) ekle:

```js
    if(_taskKategori!=='all'){
      const tips=_katTipMap[_taskKategori]||[];
      data=data.filter(t=>tips.includes(t.gorev_tipi));
    }
```

Aynı filtreyi done branch'ine de ekle (done sort'tan ÖNCE):

```js
      if(_taskKategori!=='all'){
        const tips=_katTipMap[_taskKategori]||[];
        done=done.filter(t=>tips.includes(t.gorev_tipi));
      }
```

- [ ] **Step 4: Commit**

```bash
git add index.html js/ui.js && git commit -m "feat: görev kategori filtresi — aşı/vitamin/kontrol/tedavi/bakım"
```

---

### Task 6: Test & Push

- [ ] **Step 1: Syntax kontrolü**

```bash
cd /root/egesut-erp1 && node --check js/ui.js && node --check js/api.js
```

- [ ] **Step 2: Migration'ı uygula**

```bash
# supabase_migrate tool ile 20260510000001_gorev_geri_al.sql içeriğini çalıştır
```

- [ ] **Step 3: Push**

```bash
git push
```

- [ ] **Step 4: Canlı test**

Test senaryoları:
1. Görevler → Tamamlanan → kart üstünde rapel tarihi görünür
2. Tamamlanan karta tıkla → detay modal açılır, rapel bilgisi var
3. "Geri Al" → onay → görev bekleyene döner, rapel silinir
4. 7 günden eski → geri al butonu disabled
5. Rapeli yapılmış → geri al butonu disabled + açıklama
6. Kategori filtresi: "Aşı" → sadece aşı görevleri
7. "Tümü" → tüm görevler geri gelir
