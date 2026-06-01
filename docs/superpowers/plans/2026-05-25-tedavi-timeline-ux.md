# Tedavi Timeline UX — Not Ayrımı + Görsel İyileştirme

> Topoloji: Hierarchical | 3 task | 0 paralel blok
> Model: deepseek-chat (flash)
> **DURUM: ✅ TAMAMLANDI — 2026-05-25**

**Hedef:**
1. Not eklemeyi done'dan ayır — 📝 butonu bağımsız çalışır
2. Timeline'ı görsel olarak iyileştir: dikey çizgi + düğüm sistemi, progress bar
3. Review'da tespit edilen 3 küçük bug'ı da fix et

**Etkilenen dosyalar:**
- `supabase/migrations/20260525000003_treatment_day_not.sql` (yeni)
- `supabase/migrations/99999999999999_ground_truth.sql`
- `js/ui.js` → `renderCaseTimeline`, `caseDayTamamlaAc`, `caseDayTamamla`, + 2 yeni fonksiyon
- `index.html` → CSS bloku

---

## Başlamadan Önce

```bash
sed -n '2628,2740p' /root/egesut-erp1/js/ui.js   # fmtGunSaat + renderCaseTimeline
sed -n '2773,2830p' /root/egesut-erp1/js/ui.js   # caseDayTamamlaAc + _updateKapatBtn
sed -n '215,260p' /root/egesut-erp1/index.html    # mevcut CSS bloku
```

---

## Task 1 — DB: treatment_day_not_guncelle RPC

**Uygulama:**

Yeni migration: `supabase/migrations/20260525000003_treatment_day_not.sql`

```sql
-- treatment_days.notes için ayrı güncelleme RPC
-- Not sistemi done'dan bağımsız — treatment_days.notes kolonu (zaten mevcut)
CREATE OR REPLACE FUNCTION public.treatment_day_not_guncelle(
  p_day_id  uuid,
  p_notes   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.treatment_days
  SET notes = p_notes
  WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_not_guncelle(uuid, text) TO anon, authenticated;
```

`supabase_migrate({sql: "<yukarıdaki SQL>"})` ile deploy et.

Aynı fonksiyonu `ground_truth.sql`'e de ekle (diğer RPC'lerin yanına).

**Doğrulama:**
```
supabase_rpc({function_name: "treatment_day_not_guncelle", params: '{"p_day_id":"TEST_UUID","p_notes":"test"}'})
```
→ hata fırlatmalı (UUID geçersiz) ama fonksiyon var olmalı: `42883` hatası DEĞİL, `P0001` beklenir.

**Commit:**
```bash
git add supabase/migrations/20260525000003_treatment_day_not.sql supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(treatment): treatment_day_not_guncelle RPC — not done'dan bağımsız"
git push origin main
```

---

## Task 2 — CSS: Timeline Sınıfları (index.html)

`index.html`'deki CSS bloğuna (satır ~249 civarı, `.modal-overlay` tanımından sonra) şunu ekle:

```css
/* TREATMENT TIMELINE */
.cd-progress{display:flex;align-items:center;gap:10px;margin-bottom:14px}
.cd-progress-lbl{font-size:.72rem;font-weight:700;color:var(--ink3);white-space:nowrap}
.cd-progress-track{flex:1;height:3px;background:var(--card2);border-radius:2px;overflow:hidden}
.cd-progress-fill{height:100%;background:var(--green);border-radius:2px;transition:width .5s ease}
.cd-tl-wrap{position:relative}
.cd-tl-item{display:flex;gap:12px;position:relative;padding-bottom:12px}
.cd-tl-item:not(:last-child)::before{content:'';position:absolute;left:9px;top:22px;width:2px;height:calc(100% - 10px);background:var(--card3)}
.cd-tl-item.tl-done::before{background:rgba(78,154,42,.3)}
.cd-tl-node{width:20px;height:20px;border-radius:50%;border:2px solid var(--card3);flex-shrink:0;display:flex;align-items:center;justify-content:center;margin-top:1px;background:var(--card);transition:all .2s;font-size:.65rem}
.cd-tl-item.tl-done .cd-tl-node{background:var(--green);border-color:var(--green);color:#fff}
.cd-tl-item.tl-locked{opacity:.5}
.cd-tl-content{flex:1;min-width:0;background:var(--card);border:1px solid var(--card2);border-radius:10px;padding:10px;margin-bottom:0}
.cd-tl-item.tl-done .cd-tl-content{border-color:rgba(78,154,42,.3);background:rgba(78,154,42,.04)}
.cd-day-hdr{display:flex;justify-content:space-between;align-items:center;margin-bottom:6px}
.cd-day-title{font-weight:700;font-size:.8rem;color:var(--ink)}
.cd-day-not{margin-top:6px;font-size:.72rem;color:var(--ink3);font-style:italic;line-height:1.4}
```

**Commit:** (Task 3 ile birlikte tek commit)

---

## Task 3 — JS: renderCaseTimeline + Not Sistemi + Bug Fix'ler

**Okuma:**
```bash
sed -n '2628,2830p' /root/egesut-erp1/js/ui.js
```

### 3a — renderCaseTimeline'ı yeniden yaz

Mevcut `el.innerHTML = Object.values(byDay).map(...)` bloğunu (satır 2698–2735) şununla değiştir:

```js
  // Progress hesapla
  const totalDays = sortedDays.length;
  const doneDays  = sortedDays.filter(d => d.tamamlandi).length;
  const pct       = totalDays ? Math.round(doneDays / totalDays * 100) : 0;

  const progressHtml = totalDays > 0 ? `
    <div class="cd-progress">
      <span class="cd-progress-lbl">${doneDays}/${totalDays} Tamamlandı</span>
      <div class="cd-progress-track"><div class="cd-progress-fill" style="width:${pct}%"></div></div>
    </div>` : '';

  const aktif = _curCase?.status === 'active';

  el.innerHTML = progressHtml + '<div class="cd-tl-wrap">' +
    sortedDays.map(day => {
      const saatStr   = day.time ? ` <span style="font-size:.7rem;color:var(--ink3);font-weight:400">${day.time.slice(0,5)}</span>` : '';
      const isDone    = day.tamamlandi;
      const isLocked  = !isDone && day._locked;
      const tlCls     = isDone ? 'tl-done' : isLocked ? 'tl-locked' : 'tl-active';
      const nodeIcon  = isDone ? '✓' : '';

      // Sağ taraf: done badge / locked / aksiyon butonları
      const rightSide = isDone
        ? `<span style="background:rgba(78,154,42,.12);color:var(--green);padding:2px 8px;border-radius:6px;font-size:.68rem;font-weight:700">✅ ${fmtGunSaat(day.tamamlanma_tarihi)}</span>`
        : isLocked
          ? `<span style="color:var(--ink3);font-size:.72rem">🔒</span>`
          : aktif
            ? `<div style="display:flex;gap:4px;flex-shrink:0">
                 <button onclick="caseDayTamamla('${day.day_id}')" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:3px 9px;font-size:.7rem;font-weight:700;cursor:pointer">✅</button>
                 <button onclick="caseDayNotAc('${day.day_id}','${esc(day.notes||'')}')" style="background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:7px;padding:3px 8px;font-size:.7rem;cursor:pointer">📝</button>
                 <button onclick="caseDrugFormAc('${day.day_id}')" style="background:var(--blue);color:#fff;border:none;border-radius:7px;padding:3px 8px;font-size:.7rem;cursor:pointer">+</button>
                 <button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:7px;padding:3px 6px;font-size:.7rem;color:var(--ink3);cursor:pointer">🕐</button>
                 <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.1);color:var(--red);border:1px solid rgba(192,50,26,.2);border-radius:7px;padding:3px 6px;font-size:.7rem;cursor:pointer">🗑</button>
               </div>`
            : '';

      // Not satırı: treatment_days.notes — done'dan bağımsız
      const notSatiri = day.notes
        ? `<div class="cd-day-not">📝 ${esc(day.notes)}</div>`
        : '';

      // İlaç listesi — done günlerde düzenleme butonları gizlenir
      const drugHtml = day.drugs.length
        ? day.drugs.map(d => `
            <div style="display:flex;justify-content:space-between;align-items:center;padding:4px 0;border-bottom:1px solid var(--card2)">
              <span style="font-size:.8rem"><b>${esc(d.drug)}</b> <span style="color:var(--ink3)">${d.dose} ${d.unit}${d.route?' · '+d.route:''}</span></span>
              ${aktif && !isDone ? `<div style="display:flex;gap:4px">
                <button onclick="caseDrugDuzenle('${d.administration_id}','${d.dose}','${d.unit}','${d.route||''}')" style="background:none;border:none;color:var(--blue);cursor:pointer;font-size:.9rem">✏️</button>
                <button onclick="caseDrugSil('${d.administration_id}')" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.9rem">🗑</button>
              </div>` : ''}
            </div>`).join('')
        : `<span style="color:var(--ink3);font-size:.75rem">İlaç eklenmemiş</span>`;

      return `
        <div class="cd-tl-item ${tlCls}">
          <div class="cd-tl-node">${nodeIcon}</div>
          <div class="cd-tl-content">
            <div class="cd-day-hdr">
              <span class="cd-day-title">Gün ${tarihGunNo[day.day_id]||day.day_no}${tarihSuffix[day.day_id]||''} — ${fmtTarih(day.date)}${saatStr}</span>
              ${rightSide}
            </div>
            ${notSatiri}
            <div id="drugs-${day.day_id}" style="margin-top:${notSatiri||day.drugs.length?'6px':'0'}">${drugHtml}</div>
          </div>
        </div>`;
    }).join('') + '</div>';
```

**ÖNEMLİ:** `sortedDays` zaten `day_no`'ya göre sıralı — `Object.values(byDay)` yerine `sortedDays` kullanıyoruz. Bu sıra bug'ını da çözer.

### 3b — caseDayTamamla: not sorma, direkt done

Mevcut `caseDayTamamlaAc` fonksiyonunu **sil** (artık gerekmez — "Tamamla" butonu direkt `caseDayTamamla` çağırıyor).

Mevcut `caseDayTamamla` fonksiyonunu şununla değiştir:

```js
async function caseDayTamamla(dayId) {
  try {
    await rpc('treatment_day_tamamla', { p_day_id: dayId, p_not: null });
    toast('✅ Tedavi tamamlandı');
    await pullTables(['treatment_days']);
    if (_curCase) {
      await renderCaseTimeline(_curCase.id);
      _updateKapatBtn(_curCase.id);
    }
  } catch(e) { toast('❌ ' + e.message, true); }
}
```

### 3c — caseDayNotAc + caseDayNotKaydet (yeni)

`caseDayTamamla`'nın hemen altına ekle:

```js
function caseDayNotAc(dayId, mevcutNot) {
  let box = document.getElementById('not-modal');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'not-modal';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) box.remove(); };
  box.innerHTML = `
    <div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.9rem;margin-bottom:12px">📝 Tedavi Notu</div>
      <textarea id="not-ta" rows="3" placeholder="Gözlem, reaksiyon, ek bilgi..."
        style="width:100%;border:1.5px solid var(--card3);border-radius:10px;padding:12px;font-size:.9rem;background:var(--card);color:var(--ink);outline:none;resize:none;box-sizing:border-box;margin-bottom:12px">${esc(mevcutNot||'')}</textarea>
      <div style="display:flex;gap:8px">
        <button onclick="caseDayNotKaydet('${dayId}')"
          style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">💾 Kaydet</button>
        <button onclick="document.getElementById('not-modal').remove()"
          style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;cursor:pointer">İptal</button>
      </div>
    </div>`;
  document.body.appendChild(box);
  setTimeout(() => document.getElementById('not-ta')?.focus(), 100);
}

async function caseDayNotKaydet(dayId) {
  const not = document.getElementById('not-ta')?.value?.trim() || '';
  try {
    await rpc('treatment_day_not_guncelle', { p_day_id: dayId, p_notes: not || null });
    document.getElementById('not-modal')?.remove();
    toast('📝 Not kaydedildi');
    await pullTables(['treatment_days']);
    if (_curCase) await renderCaseTimeline(_curCase.id);
  } catch(e) { toast('❌ ' + e.message, true); }
}
```

**ÖNEMLİ:** `caseDayNotAc` çağrısında `mevcutNot` JS string olarak geçiliyor. Fonksiyon imzası:
`caseDayNotAc('${day.day_id}','${esc(day.notes||'')}')`
Tek tırnak içinde esc() yapılıyor — tırnak karakteri olmayan notlar için güvenli. Not içinde tırnak varsa sorun yaratır.
**Güvenli çözüm:** `day_id` ve `notes`'u data attribute'e koy, onclick'te `this.dataset` ile oku.
Bunu da düzelt:

```js
// renderCaseTimeline'daki 📝 buton çağrısını şöyle yaz:
`<button onclick="caseDayNotAcById('${day.day_id}')" 
  data-not="${esc(day.notes||'').replace(/"/g,'&quot;')}"
  style="...">📝</button>`
```

Ve fonksiyonu:
```js
function caseDayNotAcById(dayId) {
  // Butonu bul, data-not'u oku
  const btn = document.querySelector(`button[onclick*="caseDayNotAcById('${dayId}')"]`);
  const mevcutNot = btn?.dataset?.not || '';
  caseDayNotAc(dayId, mevcutNot);
}
```

**Ya da daha temiz:** inline onclick string yerine `data-day-not` attribute kullan, `renderCaseTimeline` sonrasında event delegation ile bağla. (Mevcut kod satır içi onclick kullanıyor, tutarlılık için aynı pattern yeterli — güvenlik açısından XSS riski yok, kendi DB'si.)

Basit yol: `day.notes` içini base64'e çevir geçişte:
```js
// Butonda:
onclick="caseDayNotAc('${day.day_id}',atob('${btoa(unescape(encodeURIComponent(day.notes||'')))}'))"
```
Hepsinden temizi:
```js
// byDay map'e _notBase64 ekle:
byDay[...].notB64 = day.notes ? btoa(unescape(encodeURIComponent(day.notes))) : '';
// Butonda:
onclick="caseDayNotAc('${day.day_id}',decodeURIComponent(escape(atob('${day.notB64}'))))"
```

**Syntax check:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

**Commit:**
```bash
git add js/ui.js index.html
git commit -m "feat(treatment): timeline UX — dikey çizgi+düğüm, progress bar, not ayrımı, bug fix (sort/done-buton)"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "treatment timeline UX: .cd-tl-item/.cd-tl-node CSS ile dikey timeline, sortedDays ile render sırası fix, done günlerde ilaç butonları gizlendi, 📝 not butonu done'dan bağımsız (treatment_days.notes). caseDayNotAc base64 encode ile özel karakter güvenliği.",
  category: "code_change",
  priority: "medium",
  tags: "treatment,timeline,ux,ui.js,css"
})
```
