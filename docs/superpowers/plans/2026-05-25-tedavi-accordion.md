# Tedavi Timeline Accordion — İmplementasyon Planı

> Topoloji: Hierarchical | 2 task | 0 paralel
> Model: deepseek-chat (flash)
> DB değişikliği yok. Sadece JS + CSS.

**Hedef:** Tedavi günü kartlarını `<details>/<summary>` ile accordion yap.
- Done günler → kapalı, başlıkta ✓ tik işareti
- Aktif (sırası gelmiş) gün → açık
- Locked günler → kapalı
- CSS-only animasyon, JS sıfır

**Etkilenen dosyalar:**
- `js/ui.js` → `renderCaseTimeline` (satır ~2698–2735)
- `index.html` → CSS bloku (`.cd-tl-*` sınıfları)

---

## Başlamadan Önce

```bash
sed -n '2693,2740p' /root/egesut-erp1/js/ui.js
grep -n "cd-tl\|cd-progress\|cd-day" /root/egesut-erp1/index.html
```

---

## Task 1 — CSS: Accordion Stilleri

`index.html`'deki mevcut `.cd-tl-*` bloğunu **komple şununla değiştir:**

```css
/* TREATMENT TIMELINE */
.cd-progress{display:flex;align-items:center;gap:10px;margin-bottom:16px}
.cd-progress-lbl{font-size:.72rem;font-weight:700;color:var(--ink3);white-space:nowrap}
.cd-progress-track{flex:1;height:3px;background:var(--card2);border-radius:2px;overflow:hidden}
.cd-progress-fill{height:100%;background:var(--green);border-radius:2px;transition:width .5s ease}
.cd-tl-wrap{position:relative}
.cd-tl-item{display:flex;gap:12px;position:relative;padding-bottom:10px}
.cd-tl-item:not(:last-child)::before{content:'';position:absolute;left:9px;top:22px;width:2px;height:calc(100% - 8px);background:var(--card3)}
.cd-tl-item.tl-done::before{background:rgba(78,154,42,.3)}
.cd-tl-node{width:20px;height:20px;border-radius:50%;border:2px solid var(--card3);flex-shrink:0;display:flex;align-items:center;justify-content:center;margin-top:2px;background:var(--card);font-size:.7rem;font-weight:900;transition:all .2s}
.cd-tl-item.tl-done .cd-tl-node{background:var(--green);border-color:var(--green);color:#fff}
.cd-tl-item.tl-locked{opacity:.5}
.cd-tl-content{flex:1;min-width:0}
/* Accordion: details/summary */
.cd-acc{background:var(--card);border:1px solid var(--card2);border-radius:10px;overflow:hidden;transition:border-color .2s}
.cd-tl-item.tl-done .cd-acc{border-color:rgba(78,154,42,.28);background:rgba(78,154,42,.03)}
.cd-acc summary{list-style:none;display:flex;justify-content:space-between;align-items:center;padding:10px 12px;cursor:pointer;-webkit-tap-highlight-color:transparent;user-select:none;gap:8px}
.cd-acc summary::-webkit-details-marker{display:none}
.cd-acc summary::after{content:'▸';font-size:.75rem;color:var(--ink3);flex-shrink:0;transition:transform .2s}
.cd-acc[open] summary::after{transform:rotate(90deg)}
.cd-acc-title{font-weight:700;font-size:.8rem;color:var(--ink);display:flex;align-items:center;gap:6px;flex:1;min-width:0}
.cd-acc-right{display:flex;align-items:center;gap:6px;flex-shrink:0}
.cd-acc-body{padding:0 12px 10px;border-top:1px solid var(--card2)}
.cd-day-not{font-size:.72rem;color:var(--ink3);font-style:italic;padding:6px 0 4px;line-height:1.4}
.cd-drug-row{display:flex;justify-content:space-between;align-items:center;padding:5px 0;border-bottom:1px solid var(--card2)}
.cd-drug-row:last-child{border-bottom:none}
.cd-drug-name{font-size:.8rem;font-weight:700;color:var(--ink)}
.cd-drug-meta{font-size:.78rem;color:var(--ink3)}
.cd-acc-actions{display:flex;gap:6px;flex-wrap:wrap;padding-top:10px;border-top:1px solid var(--card2);margin-top:6px}
```

**Commit:** Task 2 ile birlikte.

---

## Task 2 — JS: renderCaseTimeline — details/summary Template

**Okuma:**
```bash
sed -n '2693,2740p' /root/egesut-erp1/js/ui.js
```

`el.innerHTML = progressHtml + '<div class="cd-tl-wrap">' + sortedDays.map(...)` bloğunu bul.
`sortedDays.map(day => { ... })` içini **komple şununla değiştir:**

```js
    sortedDays.map(day => {
      const saatStr  = day.time ? `<span style="font-size:.68rem;color:var(--ink3);font-weight:400;margin-left:4px">${day.time.slice(0,5)}</span>` : '';
      const isDone   = day.tamamlandi;
      const isLocked = !isDone && day._locked;
      const tlCls    = isDone ? 'tl-done' : isLocked ? 'tl-locked' : 'tl-active';
      const openAttr = (!isDone && !isLocked) ? 'open' : '';  // aktif gün açık, diğerleri kapalı
      const nodeIcon = isDone ? '✓' : '';
      const gunNo    = `Gün ${tarihGunNo[day.day_id]||day.day_no}${tarihSuffix[day.day_id]||''}`;

      // Başlık sağ taraf
      const badge = isDone
        ? `<span style="background:rgba(78,154,42,.12);color:var(--green);padding:2px 8px;border-radius:6px;font-size:.68rem;font-weight:700">✅ ${fmtGunSaat(day.tamamlanma_tarihi)}</span>`
        : isLocked
          ? `<span style="color:var(--ink3);font-size:.72rem">🔒</span>`
          : '';

      // Not satırı (treatment_days.notes)
      const notHtml = day.notes
        ? `<div class="cd-day-not">📝 ${esc(day.notes)}</div>`
        : '';

      // İlaç listesi
      const aktif = _curCase?.status === 'active';
      const drugHtml = day.drugs.length
        ? `<div style="margin-top:2px">${day.drugs.map(d => `
            <div class="cd-drug-row">
              <div><span class="cd-drug-name">${esc(d.drug)}</span> <span class="cd-drug-meta">${d.dose} ${d.unit}${d.route?' · '+d.route:''}</span></div>
              ${aktif && !isDone ? `<div style="display:flex;gap:2px">
                <button onclick="caseDrugDuzenle('${d.administration_id}','${d.dose}','${d.unit}','${d.route||''}')" style="background:none;border:none;color:var(--blue);cursor:pointer;font-size:.85rem;padding:2px">✏️</button>
                <button onclick="caseDrugSil('${d.administration_id}')" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.85rem;padding:2px">🗑</button>
              </div>` : ''}
            </div>`).join('')}</div>`
        : `<span style="color:var(--ink3);font-size:.75rem;display:block;padding:4px 0">İlaç eklenmemiş</span>`;

      // Aksiyon butonları (sadece aktif + done değil + locked değil)
      const actionsHtml = aktif && !isDone && !isLocked ? `
        <div class="cd-acc-actions">
          <button onclick="caseDayTamamla('${day.day_id}')" style="background:var(--green);color:#fff;border:none;border-radius:8px;padding:7px 14px;font-size:.78rem;font-weight:700;cursor:pointer">✅ Tamamla</button>
          <button onclick="caseDayNotAcById('${day.day_id}')" style="background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:8px;padding:7px 12px;font-size:.78rem;cursor:pointer">📝 Not</button>
          <button onclick="caseDrugFormAc('${day.day_id}')" style="background:var(--blue);color:#fff;border:none;border-radius:8px;padding:7px 12px;font-size:.78rem;cursor:pointer">+ İlaç</button>
          <button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:7px 10px;font-size:.78rem;color:var(--ink3);cursor:pointer">🕐</button>
          <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.18);border-radius:8px;padding:7px 10px;font-size:.78rem;cursor:pointer">🗑</button>
        </div>` : '';

      // data-not: base64 encode ile özel karakter güvenliği
      const notB64 = day.notes ? btoa(unescape(encodeURIComponent(day.notes))) : '';

      return `
        <div class="cd-tl-item ${tlCls}">
          <div class="cd-tl-node">${nodeIcon}</div>
          <div class="cd-tl-content">
            <details class="cd-acc" ${openAttr}>
              <summary>
                <div class="cd-acc-title">
                  <span>${gunNo} — ${fmtTarih(day.date)}${saatStr}</span>
                </div>
                <div class="cd-acc-right">${badge}</div>
              </summary>
              <div class="cd-acc-body" id="drugs-${day.day_id}">
                ${notHtml}
                ${drugHtml}
                ${actionsHtml}
              </div>
            </details>
            <button data-day-id="${day.day_id}" data-not-b64="${notB64}"
              style="display:none" id="not-trigger-${day.day_id}"></button>
          </div>
        </div>`;
    }).join('')
```

**caseDayNotAcById güncelleme** — mevcut fonksiyonu bul, şununla değiştir:

```js
function caseDayNotAcById(dayId) {
  const trigger = document.getElementById('not-trigger-' + dayId);
  const b64 = trigger?.dataset?.notB64 || '';
  const mevcutNot = b64 ? decodeURIComponent(escape(atob(b64))) : '';
  caseDayNotAc(dayId, mevcutNot);
}
```

**Syntax check:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

**Commit:**
```bash
git add js/ui.js index.html
git commit -m "feat(treatment): timeline accordion — details/summary, done günler ✓ kapalı, aktif gün açık"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "treatment timeline accordion: <details>/<summary> HTML native accordion kullanıldı — JS sıfır toggle. done günler kapalı+✓, aktif gün open attr ile açık. data-not-b64 ile base64 encode not güvenliği. CSS .cd-acc/.cd-acc-body/.cd-acc-actions.",
  category: "code_change",
  priority: "medium",
  tags: "treatment,accordion,details,summary,ui.js,css"
})
```
