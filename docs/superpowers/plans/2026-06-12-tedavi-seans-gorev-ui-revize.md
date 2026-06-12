# Tedavi Seans → Görev Kartı UI Revizyonu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Görev listesinde her tedavi seansını ayrı kart olarak (hayvan/gün ayracı altında, checkbox + ▾ inline aksiyon) göster; saatsiz ilaç dump'ını ve "eklenen seans görünmez" bug'ını düzelt; tedavi modalını iki net bölüme sadeleştir.

**Architecture:** Tamamı frontend. DB modeli (`TEDAVI_SEANS` görevleri + `treatment_day_uygulamalar` + `seans_tamamla` RPC + `computeSeansState`) zaten hazır — yeni RPC/migration YOK. `loadTasks` render bloğu seans gruplama + yeni kart fonksiyonlarıyla yeniden yazılır; `renderCaseTimeline` görsel olarak sadeleşir.

**Tech Stack:** Vanilla JS (innerHTML template literal pattern), IndexedDB (`idbGetAll`), Playwright (smoke/e2e), CSS in `index.html`.

**Spec:** `docs/superpowers/specs/2026-06-12-tedavi-seans-gorev-ui-revize-design.md`

> **Test stratejisi (proje gerçeği):** Bu proje vanilla JS innerHTML render + Playwright e2e kullanır; render fonksiyonları için birim TDD harness'ı yoktur (bkz. CLAUDE.md "Vanilla JS UI Kuralları"). Bu yüzden her task'ta doğrulama = `node --check` (sözdizimi) + mevcut Playwright smoke (regresyon) + açık manuel kontrol listesi. Yeni e2e fixture yazılmaz (canlı Supabase'e bağımlı).

---

## Dosya Haritası

| Dosya | Sorumluluk | Değişiklik |
|---|---|---|
| `index.html` | Seans görev kartı + ayraç + inline aksiyon CSS; modal section-label CSS | CSS ekleme (~40 satır) |
| `js/ui.js` | `loadTasks` render bloğu (gruplama + gizleme + dump fix); yeni `renderSeansGorevKart`, `renderSeansGrupAyrac`, `toggleSeansAksiyon`; `updateTaskBadge` fix; `renderCaseTimeline` sadeleştirme | Modify |
| `js/forms.js` | `seansTamamla` — görev listesi tazeleme | Modify (1 blok) |

Mevcut yeniden kullanılan: `computeSeansState`, `fmtSeansSaat`, `fmtBeklemeSure`, `fmtSaatKisa`, `SEANS_STATE` (config.js), `seansTamamla`+`rpcSeansTamamla`, `renderTask`, `fmtTarih`, `esc`, `getState`.

---

## Task 1: Seans görev kartı CSS (index.html)

**Files:**
- Modify: `index.html` (seans CSS bloğunun sonu, `.seans-btn-iptal` satırından sonra ~395)

- [ ] **Step 1: CSS bloğunu ekle**

`index.html`'de `.seans-btn-iptal{...}` satırının hemen altına (kapanış `</style>` öncesi) ekle:

```css
/* --- Görev listesi seans kartı (BUG-059 revizyon) --- */
.seans-grup-ayrac{font-size:.7rem;font-weight:800;color:var(--ink2);padding:10px 4px 4px;display:flex;align-items:center;gap:5px;letter-spacing:.01em}
.seans-grup-wrap{display:flex;flex-direction:column;gap:6px;margin-bottom:10px;padding-left:6px;border-left:2px solid var(--card3)}
.seans-gorev-card{background:var(--card);border:1px solid var(--card3);border-left:4px solid var(--green);border-radius:var(--r2);padding:9px 11px;display:flex;align-items:center;gap:9px;flex-wrap:wrap}
.seans-gorev-card.s-overdue{border-left-color:var(--red)}
.seans-gorev-card.s-now{border-left-color:var(--blue)}
.seans-gorev-card.s-due-soon{border-left-color:var(--amber)}
.seans-gorev-card.done-card{opacity:.5}
.sg-check{width:24px;height:24px;flex-shrink:0;border:2px solid var(--card3);border-radius:7px;background:none;cursor:pointer;font-size:.9rem;color:#fff;display:flex;align-items:center;justify-content:center;padding:0;line-height:1}
.sg-check.sg-done{background:var(--green);border-color:var(--green)}
.sg-saat{font-weight:800;font-variant-numeric:tabular-nums;font-size:.9rem;color:var(--ink);flex-shrink:0;min-width:46px}
.sg-info{flex:1;min-width:0}
.sg-ilac{font-size:.82rem;font-weight:600;color:var(--ink)}
.sg-meta{font-size:.67rem;color:var(--ink3);margin-top:1px;display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.sg-now{color:var(--blue);font-weight:800}
.sg-late{color:var(--red);font-weight:800}
.sg-soon{color:var(--amber);font-weight:700}
.sg-expand{background:none;border:none;color:var(--ink3);font-size:1rem;cursor:pointer;padding:4px 6px;flex-shrink:0;line-height:1}
.sg-actions{flex-basis:100%;border-top:1px solid var(--card2);padding-top:7px;margin-top:2px}
.sg-act-iade{background:none;border:1px solid var(--card3);border-radius:7px;padding:8px 11px;font-size:.74rem;font-weight:600;color:var(--ink2);cursor:pointer;width:100%;text-align:left}
/* Modal section etiketi */
.cd-sec-lbl{font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-top:8px;margin-bottom:2px}
```

- [ ] **Step 2: HTML geçerliliğini doğrula**

Run: `node -e "const h=require('fs').readFileSync('index.html','utf8'); const o=(h.match(/<style/g)||[]).length, c=(h.match(/<\/style>/g)||[]).length; if(o!==c) throw new Error('style tag mismatch '+o+'/'+c); console.log('style tags OK:',o);"`
Expected: `style tags OK: 1` (veya mevcut sayı; açılış=kapanış)

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat(BUG-059): seans görev kartı + ayraç CSS (görev listesi)"
```

---

## Task 2: Yeni render fonksiyonları + ▾ toggle (js/ui.js)

**Files:**
- Modify: `js/ui.js` (`renderTask` fonksiyonunun bittiği `}` satırından sonra, `toggleSub`'tan önce ~524)

- [ ] **Step 1: `renderSeansGrupAyrac`, `renderSeansGorevKart`, `toggleSeansAksiyon` ekle**

`js/ui.js`'de `renderTask` fonksiyonunun kapanışından (`}` — ~satır 524) hemen sonra ekle:

```js
// Görev listesi: hayvan+gün seans grubu ayracı
function renderSeansGrupAyrac(g){
  const gun = `Gün ${g.gunNo}${g.totalGun?'/'+g.totalGun:''}`;
  const dis = g.disease ? ` · 🏥 ${esc(g.disease)}` : '';
  const tarih = g.date ? ` · ${fmtTarih(g.date)}` : '';
  return `<div class="seans-grup-ayrac">🐄 ${esc(g.animalLabel||'—')} · ${gun}${dis}${tarih}</div>`;
}

// Görev listesi: tek seans kartı (checkbox + ▾ inline iade)
function renderSeansGorevKart(task, seans, opts={}){
  const s = { ...seans, planned_date: seans.planned_date || opts.date };
  const state = computeSeansState(s);
  const kapali = state==='done' || state==='cancelled';
  const saat = fmtSeansSaat(s.planned_time) || '—';
  const drug = esc(opts.drugName || 'İlaç');
  const meta = [`${s.dose||''}${s.unit||''}`, s.route].filter(Boolean).join(' · ');
  const durumEk = {
    'now':       '<span class="sg-now">◀ şimdi</span>',
    'overdue':   `<span class="sg-late">⚠ ${esc(fmtBeklemeSure(s))} gecikti</span>`,
    'due-soon':  `<span class="sg-soon">◐ ${esc(fmtBeklemeSure(s))} sonra</span>`,
  }[state] || '';
  if(kapali){
    const dt = state==='done'
      ? `✓ ${esc(fmtSaatKisa(s.uygulama_tamamlandi_at)||'')}`.trim()
      : '✕ Yapılamadı';
    return `<div class="seans-gorev-card s-${state} done-card">
      <span class="sg-check sg-done">✓</span>
      <span class="sg-saat">${esc(saat)}</span>
      <div class="sg-info"><div class="sg-ilac">${drug}</div><div class="sg-meta">${esc(meta)}</div></div>
      <span class="seans-chip s-${state}">${dt}</span>
    </div>`;
  }
  return `<div class="seans-gorev-card s-${state}" id="sg-${task.id}">
    <button class="sg-check" onclick="event.stopPropagation();seansTamamla('${seans.id}',false,this)" title="Uygulandı"></button>
    <span class="sg-saat">${esc(saat)}</span>
    <div class="sg-info"><div class="sg-ilac">${drug}</div><div class="sg-meta">${esc(meta)}${durumEk?' '+durumEk:''}</div></div>
    <button class="sg-expand" onclick="event.stopPropagation();toggleSeansAksiyon('${task.id}')" title="Diğer işlemler">▾</button>
    <div class="sg-actions" id="sga-${task.id}" style="display:none">
      <button class="sg-act-iade" onclick="event.stopPropagation();seansTamamla('${seans.id}',true,this)">↩ Yapılmadı · stok iade</button>
    </div>
  </div>`;
}

// Seans kartı ▾ inline aksiyon aç/kapat
function toggleSeansAksiyon(taskId){
  const el = document.getElementById('sga-'+taskId);
  if(!el) return;
  const open = el.style.display !== 'none';
  el.style.display = open ? 'none' : 'block';
  const exp = document.querySelector('#sg-'+taskId+' .sg-expand');
  if(exp) exp.textContent = open ? '▾' : '▴';
}
```

- [ ] **Step 2: Sözdizimini doğrula**

Run: `node --check js/ui.js`
Expected: çıktı yok (exit 0)

- [ ] **Step 3: Fonksiyonların global window'a sızdığını doğrula** (bu proje fonksiyonları global script scope'ta tanımlar — onclick stringleri için erişilebilir olmalı)

Run: `grep -nE "function renderSeansGorevKart|function renderSeansGrupAyrac|function toggleSeansAksiyon" js/ui.js`
Expected: 3 satır eşleşir

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat(BUG-059): renderSeansGorevKart + ayraç + ▾ toggle fonksiyonları"
```

---

## Task 3: loadTasks — filtre fix + dump fix + seans gruplama render (js/ui.js)

**Files:**
- Modify: `js/ui.js` `loadTasks` — filtre satırı (~441), `_dayDrugMap` kurulumu (~459-463), render bloğu (~454-480)

- [ ] **Step 1: TEDAVI_SEANS'ı üst seviyeye çıkar (filtre fix)**

`js/ui.js:441` satırını:
```js
    let data=all.filter(t=>!t.tamamlandi&&!t.iptal&&(!t.parent_id||_doneIds.has(t.parent_id)));
```
şununla değiştir:
```js
    let data=all.filter(t=>!t.tamamlandi&&!t.iptal&&(t.gorev_tipi==='TEDAVI_SEANS'||!t.parent_id||_doneIds.has(t.parent_id)));
```

- [ ] **Step 2: Saatsiz ilaç dump fix + drug_products yükle**

`js/ui.js`'de `_dayDrugMap` kurulumunu (`_allDrugAdmins.forEach(...)` bloğu, ~459-463) şununla değiştir:

```js
    const _allDrugProducts=await idbGetAll('drug_products').catch(()=>[]);
    const _prodMap=Object.fromEntries(_allDrugProducts.map(p=>[p.id,p]));
    const _dayDrugMap={};
    _allDrugAdmins.forEach(da=>{
      if(da.seans_admin_id) return; // saatli ilaçlar seans kartına gider, güne dump edilmez
      if(!_dayDrugMap[da.treatment_day_id])_dayDrugMap[da.treatment_day_id]=[];
      _dayDrugMap[da.treatment_day_id].push({name:_stokNameMap[da.stok_id]||'İlaç',dose:da.dose,unit:da.unit,route:da.route});
    });
```

- [ ] **Step 3: Seans verisi için map'leri kur (treatment_days zaten `_allTDays`'te)**

`js/ui.js`'de `_dayDiseaseMap` kurulumundan hemen sonra (`_allTDays.forEach(td=>{...})` bloğunun ardından, ~471) ekle:

```js
    const _allSeans=await idbGetAll('treatment_day_uygulamalar').catch(()=>[]);
    const _seansById=Object.fromEntries(_allSeans.map(s=>[s.id,s]));
    const _tdById=Object.fromEntries(_allTDays.map(td=>[td.id,td]));
    const _caseDayCount={};
    _allTDays.forEach(td=>{ _caseDayCount[td.case_id]=(_caseDayCount[td.case_id]||0)+1; });
```

- [ ] **Step 4: Render bloğunu yeniden yaz (gruplama + gizleme)**

`js/ui.js`'de mevcut render bloğunu (`el.innerHTML=data.slice(0,150).map(t=>{ ... }).join('');` — ~472-480) şununla değiştir:

```js
    // --- Seans görevlerini ayır, gruplara böl ---
    const seansDayIds=new Set();
    data.forEach(t=>{ if(t.gorev_tipi==='TEDAVI_SEANS'){ const sd=_seansById[t.seans_admin_id]; if(sd?.treatment_day_id)seansDayIds.add(sd.treatment_day_id); } });
    // Seansı olan TEDAVI_GUN kartlarını gizle (sadece saatsiz-ilaç günleri kart olur)
    const grupMap={};
    data.forEach(t=>{
      if(t.gorev_tipi!=='TEDAVI_SEANS')return;
      const seans=_seansById[t.seans_admin_id]; if(!seans)return;
      const dayId=seans.treatment_day_id;
      const key=(t.hayvan_id||'')+'|'+dayId;
      if(!grupMap[key]){
        const td=_tdById[dayId];
        const animal=getState('animals').find(a=>a.id===t.hayvan_id);
        grupMap[key]={ hayvan_id:t.hayvan_id, day_id:dayId,
          date:t.hedef_tarih||td?.treatment_date||'',
          gunNo:td?.day_no||'?', totalGun:td?_caseDayCount[td.case_id]||0:0,
          animalLabel:animal?(animal.kupe_no||animal.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'—'),
          disease:_dayDiseaseMap[dayId]||'', items:[] };
      }
      grupMap[key].items.push({ task:t, seans,
        drugName:_prodMap[seans.drug_product_id]?.brand_name||_stokNameMap[seans.stok_id]||'İlaç' });
    });
    // --- Blokları (normal kart + seans grubu) tek listede sırala ---
    const bloklar=[];
    data.forEach(t=>{
      if(t.gorev_tipi==='TEDAVI_SEANS')return;
      if(t.gorev_tipi==='TEDAVI_GUN'){ try{ if(seansDayIds.has(JSON.parse(t.aciklama||'{}').day_id))return; }catch(e){} }
      const planTime=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
      bloklar.push({ sort:(t.hedef_tarih||'')+'|'+(planTime||'~')+'|n', type:'normal', task:t });
    });
    Object.values(grupMap).forEach(g=>{
      g.items.sort((a,b)=>(a.seans.planned_time||'').localeCompare(b.seans.planned_time||''));
      const ilk=g.items[0]?.seans.planned_time||'';
      bloklar.push({ sort:(g.date||'')+'|'+(ilk||'~')+'|s', type:'seans', grup:g });
    });
    bloklar.sort((a,b)=>a.sort.localeCompare(b.sort));
    el.innerHTML=bloklar.slice(0,200).map(b=>{
      if(b.type==='seans'){
        const g=b.grup;
        return renderSeansGrupAyrac(g)+'<div class="seans-grup-wrap">'+
          g.items.map(it=>renderSeansGorevKart(it.task,it.seans,{drugName:it.drugName,date:g.date})).join('')+'</div>';
      }
      const t=b.task;
      const _diff=Math.floor((new Date(t.hedef_tarih)-Date.now())/86400000);
      const _clsBase=_diff<=3?'near':'';
      const _clsMid=t.hedef_tarih===today?'soon':_clsBase;
      const cls=t.hedef_tarih<today?'late':_clsMid;
      const _tDrugs=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return _dayDrugMap[JSON.parse(t.aciklama||'{}').day_id]||[];}catch(e){return [];}})():[];
      const _tDisease=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return _dayDiseaseMap[JSON.parse(t.aciklama||'{}').day_id]||'';}catch(e){return '';}})():'';
      return renderTask(t,cls,allSubs.filter(s=>s.parent_id===t.id),_tDrugs,_tDisease);
    }).join('');
```

- [ ] **Step 5: Sözdizimini doğrula**

Run: `node --check js/ui.js`
Expected: çıktı yok (exit 0)

- [ ] **Step 6: pullTables'a treatment_day_uygulamalar dahil mi kontrol et**

`loadTasks` başındaki `pullTables([...])` çağrısı (`js/ui.js:414`) seans tablosunu çekmeli. Kontrol:

Run: `sed -n '414p' js/ui.js`
Expected çıktı `treatment_day_uygulamalar` içermeli. İçermiyorsa satırı şu hale getir:
```js
    if(navigator.onLine) await pullTables(['gorev_log','treatment_days','cases','diseases','treatment_day_uygulamalar','drug_administrations','drug_products','stok']).catch(()=>{});
```

- [ ] **Step 7: Commit**

```bash
git add js/ui.js
git commit -m "fix(BUG-059): loadTasks seans gruplama + saatsiz dump fix + filtre fix"
```

---

## Task 4: updateTaskBadge + seansTamamla görev listesi tazeleme

**Files:**
- Modify: `js/ui.js` `updateTaskBadge` (~554)
- Modify: `js/forms.js` `seansTamamla` (~1726-1732 arası, catch'ten önce)

- [ ] **Step 1: updateTaskBadge — TEDAVI_SEANS'ı üst seviye say**

`js/ui.js:554`:
```js
    const tasks=all.filter(t=>!t.tamamlandi&&(!t.parent_id||doneIds.has(t.parent_id)));
```
şununla değiştir:
```js
    const tasks=all.filter(t=>!t.tamamlandi&&(t.gorev_tipi==='TEDAVI_SEANS'||!t.parent_id||doneIds.has(t.parent_id)));
```

- [ ] **Step 2: seansTamamla — görev listesi açıksa tazele**

`js/forms.js`'de `seansTamamla` içinde, `if (_curTaskDet?.gorev_tipi === 'TEDAVI_GUN') {...}` bloğunun hemen ardından (catch'ten önce, ~1732) ekle:

```js
    // Görev listesi görünürse tazele (seans kartları oradan tamamlanabilir)
    try {
      const _tb=document.getElementById('tasks-body');
      if(_tb && _tb.offsetParent!==null) await loadTasks(_curTaskFilter||'today');
      if(typeof updateTaskBadge==='function') updateTaskBadge();
    } catch(e){ /* sessiz */ }
```

- [ ] **Step 3: Sözdizimini doğrula**

Run: `node --check js/ui.js && node --check js/forms.js`
Expected: çıktı yok (exit 0)

- [ ] **Step 4: Commit**

```bash
git add js/ui.js js/forms.js
git commit -m "fix(BUG-059): updateTaskBadge seans + seansTamamla görev listesi tazeleme"
```

---

## Task 5: Tedavi modalı sadeleştirme (renderCaseTimeline)

**Files:**
- Modify: `js/ui.js` `renderCaseTimeline` — `drugHtml` (~4482-4491), `seansHtml` (~4494-4497), `actionsHtml` (~4500-4510)

- [ ] **Step 1: Saatsiz ilaçlara section etiketi ekle**

`js/ui.js`'de `drugHtml` tanımını (~4482) şununla değiştir — başına "Hızlı ilaçlar" etiketi (sadece seans da varsa, ayırt etmek için):

```js
      const drugHtml = day.drugs.length
        ? `${sessions.length ? '<div class="cd-sec-lbl">💊 Hızlı ilaçlar (saatsiz)</div>' : ''}<div style="margin-top:2px">${day.drugs.map(d => `
            <div class="cd-drug-row">
              <div><span class="cd-drug-name">${esc(d.drug)}</span> <span class="cd-drug-meta">${d.dose} ${d.unit}${d.route?' · '+d.route:''}</span></div>
              ${aktif && !isDone ? `<div style="display:flex;gap:2px">
                <button onclick="caseDrugDuzenle('${d.administration_id}','${d.dose}','${d.unit}','${d.route||''}')" style="background:none;border:none;color:var(--blue);cursor:pointer;font-size:.85rem;padding:2px">✏️</button>
                <button onclick="caseDrugSil('${d.administration_id}')" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.85rem;padding:2px">🗑</button>
              </div>` : ''}
            </div>`).join('')}</div>`
        : (sessions.length ? '' : `<span style="color:var(--ink3);font-size:.75rem;display:block;padding:4px 0">İlaç eklenmemiş</span>`);
```

- [ ] **Step 2: Seans planı etiketini class'a çevir**

`js/ui.js`'de `seansHtml` içindeki inline-style etiket satırını (~4495):
```js
        <div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-top:8px">⏰ Seans Planı</div>
```
şununla değiştir:
```js
        <div class="cd-sec-lbl">⏰ Seans Planı</div>
```

- [ ] **Step 3: Aksiyon çubuğunu sadeleştir (ana akış + ikincil ikon grubu)**

`js/ui.js`'de `actionsHtml` tanımını (~4500-4510) şununla değiştir — ana butonlar solda, ikincil (Saat/Sil) sağda küçük ikon grubu:

```js
      const actionsHtml = aktif && !isDone ? `
        <div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:8px;padding-top:8px;border-top:1px solid var(--card3);align-items:center">
          ${!isLocked && !sessions.length ? `<button onclick="caseDayTamamla('${day.day_id}')" style="flex:1;min-width:80px;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:700">✅ Tamamla</button>` : ''}
          ${!sessions.length ? `<button onclick="caseDrugFormAc('${day.day_id}')" style="flex:1;min-width:72px;background:var(--blue);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:600">+ İlaç</button>` : ''}
          ${!kilitliSeans ? `<button onclick="caseSeansFormAc('${day.day_id}')" style="flex:1;min-width:72px;background:${sessions.length?'var(--card2)':'none'};color:var(--ink2);border:1px solid var(--card3);border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:600">⏰ ${sessions.length ? 'Planı Düzenle' : 'Seans Planla'}</button>` : ''}
          <button onclick="caseDayNotAcById('${day.day_id}')" style="flex:1;min-width:64px;background:var(--card2);color:var(--ink2);border:1px solid var(--card3);border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer">📝 Not</button>
          <span style="display:flex;gap:2px;margin-left:auto">
            ${!sessions.length ? `<button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:7px;padding:8px 9px;font-size:.8rem;color:var(--ink3);cursor:pointer" title="Saat ekle">🕐</button>` : ''}
            <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.06);color:var(--red);border:1px solid rgba(192,50,26,.15);border-radius:7px;padding:8px 9px;font-size:.8rem;cursor:pointer" title="Günü sil">🗑</button>
          </span>
        </div>
        ${isLocked ? '<div style="margin-top:4px;font-size:.68rem;color:var(--ink3);padding:0 2px">⏳ Önceki gün tamamlanmadan bu gün tamamlanamaz</div>' : ''}
        ${sessions.length && !isLocked ? '<div style="margin-top:4px;font-size:.68rem;color:var(--ink3);padding:0 2px">Son seans kapatılınca gün otomatik tamamlanır</div>' : ''}` : '';
```

- [ ] **Step 4: Sözdizimini doğrula**

Run: `node --check js/ui.js`
Expected: çıktı yok (exit 0)

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(BUG-059): tedavi modalı iki bölüm net + aksiyon çubuğu sade"
```

---

## Task 6: Doğrulama (regresyon + manuel) ve push

**Files:** yok (doğrulama)

- [ ] **Step 1: Tüm değişen JS sözdizimini doğrula**

Run: `node --check js/ui.js && node --check js/forms.js && echo "SYNTAX OK"`
Expected: `SYNTAX OK`

- [ ] **Step 2: gitnexus_detect_changes ile etki alanını doğrula**

Run (MCP): `gitnexus_detect_changes({scope:"all"})`
Expected: Etkilenen semboller `loadTasks`, `renderTask`, `renderSeansGorevKart`, `renderSeansGrupAyrac`, `toggleSeansAksiyon`, `updateTaskBadge`, `seansTamamla`, `renderCaseTimeline` ile sınırlı; beklenmeyen sembol yoksa devam.

- [ ] **Step 3: Mevcut Playwright smoke testini çalıştır (regresyon)**

Run: `npx playwright test tests/smoke.spec.js --reporter=line 2>&1 | tail -20`
Expected: smoke testleri PASS (veya değişiklik öncesiyle aynı sonuç — bu revizyon smoke kapsamını bozmamalı). Eğer ortam (Supabase/baseURL) nedeniyle zaten kırıksa, çıktıyı not et ve manuel kontrole geç.

- [ ] **Step 4: Manuel kontrol listesi (tarayıcı — saha cihazı/responsive)**

Aşağıdakileri elle doğrula ve her birini işaretle:
- [ ] Seanslı tedavi günü olan bir vaka için Görevler sayfasında: her seans **ayrı kart**, üstte `🐄… · Gün N/M · 🏥…` ayracı
- [ ] Seanslı günün TEDAVI_GUN kartı **listede görünmüyor** (sadece ayraç)
- [ ] Saatsiz ilaçlı gün (seans yok) için: tek TEDAVI_GUN kartı, **yalnızca saatsiz** ilaçları listeli (başka günün ilaçları sızmıyor)
- [ ] Yeni seans ekle (modal → Seans Planla) → kaydet → Görevler'de **anında görünüyor** ("görünmez" bug'ı gitti)
- [ ] Seans kartı checkbox'a dokun → "✓ Seans tamamlandı" toast, kart done görünümüne geçiyor, geç ise meta'da ⚠ uyarı
- [ ] Seans kartı `▾` → altta "↩ Yapılmadı · stok iade" açılıyor, tıkla → iade toast, kart "✕ Yapılamadı"
- [ ] `now`/`overdue`/`due-soon` durumlarında sol kenar rengi ve `◀ şimdi` / `⚠ gecikti` göstergesi doğru
- [ ] Tedavi modalı: "💊 Hızlı ilaçlar (saatsiz)" ve "⏰ Seans Planı" bölümleri net; aksiyon çubuğunda 🕐/🗑 sağda küçük ikon; görsel pastoral temayla tutarlı (font/radius/spacing)

- [ ] **Step 5: Push**

```bash
git push origin feature/asilama-tam-mimari
```
Expected: pre-push hook çalışır, push başarılı.

---

## Self-Review Notları (plan yazarı tarafından)

- **Spec kapsam:** A1 (filtre)→Task 3.1+4.1; A2 (TEDAVI_GUN gizle)→Task 3.4; A3 (ayraç)→Task 2+3; A4 (seans kartı)→Task 1+2; A5 (dump fix)→Task 3.2; B (modal)→Task 5; C (RPC yok)→teyit, yeni RPC eklenmedi. Tüm spec maddeleri karşılandı.
- **Bağımlılıklar:** `computeSeansState`/`fmtBeklemeSure`/`fmtSaatKisa`/`fmtSeansSaat` (ui.js'te mevcut), `seansTamamla`/`rpcSeansTamamla` (forms.js/api.js mevcut), `getState`/`esc`/`fmtTarih` (mevcut). Yeni tanımlanan: `renderSeansGorevKart`, `renderSeansGrupAyrac`, `toggleSeansAksiyon` (Task 2) — Task 3'te kullanılmadan önce tanımlı.
- **İsim tutarlılığı:** `seansTamamla(seansId, uygulanmadi, btn)` imzası her çağrıda korunur; seans kayıt id'si `seans.id` (treatment_day_uygulamalar PK), görev id'si `task.id` — kart id'leri `sg-${task.id}`/`sga-${task.id}` ile eşleşir.
```
