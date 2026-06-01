# UI — Tohumlama Form Genişlemesi + Kızgınlık Kart Güncellemesi — Plan D

> Topoloji: Mesh | 4 task | 1 paralel blok (Task 2 + Task 3)
> Model: deepseek-chat (flash)
> Soru varsa devam etmeden önce sor. JS değişikliklerinde node --check zorunlu.

**Hedef:**
- Tohumlama modalına ek uygulama bölümü (GnRH/PG/Vitamin chip'leri + stok dropdown)
- Tohumlama modalına "Sorun tespit edildi" toggle
- Kızgınlık kartına POSTPARTUM_GOZLEM badge + bağlı case bağlantı göstergesi

**Etkilenen dosyalar:**
- `index.html` → tohumlama modal bölümü
- `js/forms.js` → submitInsem, ek uygulama listesi yönetimi
- `js/ui.js` → _uremeKizginlik kart render

**Bağımlılık:** Plan-C tamamlanmış olmalı (ek_uygulamalar DB'de mevcut, kizginlik_vaka_ac RPC hazır).

---

## Başlamadan Önce

Sırayla oku:
```bash
# 1. Tohumlama modalı (index.html)
grep -n "m-insem\|m-insem-tekrar" /root/egesut-erp1/index.html
# Satır numarasını bul → modal bloğunun tamamını oku

# 2. submitInsem fonksiyonu
grep -n "submitInsem\|async function submitInsem" /root/egesut-erp1/js/forms.js
# Satır numarasını bul → fonksiyonun tamamını oku

# 3. _uremeKizginlik card() içi
sed -n '1316,1351p' /root/egesut-erp1/js/ui.js

# 4. Mevcut stok listesi — hangi kategoriler var, GnRH hangi kategoride
# supabase_query({table: "stok", select: "id,urun_adi,kategori,birim", limit: 50})

# 5. trSpermaModStok fonksiyonu (sperma stok yükleme pattern'i — ek uygulama için referans)
grep -n "trSpermaModStok\|spermaModStok" /root/egesut-erp1/js/forms.js | head -5
```

Sonra planı oku, net olmayan şey varsa sor.

---

## Task 1 — index.html: Tohumlama Modalı Genişletme

**Uygulama:**

Tohumlama modalında (`#m-insem`) Hekim field'ından sonra, submit butonundan önce iki yeni bölüm ekle:

```html
<!-- EK UYGULAMA BÖLÜMÜ -->
<div class="fg" id="ek-uygulama-wrap" style="border:1px solid var(--card3);border-radius:10px;padding:10px;background:var(--card2)">
  <div style="font-size:.75rem;font-weight:700;color:var(--ink2);margin-bottom:8px">💊 Ek Uygulamalar</div>

  <!-- Quick chip'ler -->
  <div style="display:flex;flex-wrap:wrap;gap:5px;margin-bottom:8px" id="ek-chip-row">
    <button type="button" class="ek-chip" data-tur="GnRH"      onclick="ekChipSec(this)">GnRH</button>
    <button type="button" class="ek-chip" data-tur="PG"        onclick="ekChipSec(this)">PG</button>
    <button type="button" class="ek-chip" data-tur="E Vitamini" onclick="ekChipSec(this)">E-Vit</button>
    <button type="button" class="ek-chip" data-tur="B12"       onclick="ekChipSec(this)">B12</button>
    <button type="button" class="ek-chip" data-tur="Selenium"  onclick="ekChipSec(this)">Se</button>
    <button type="button" class="ek-chip" data-tur="Diğer"     onclick="ekChipSec(this)">+ Diğer</button>
  </div>

  <!-- Stok + doz satırı (chip seçilince görünür) -->
  <div id="ek-stok-row" style="display:none;gap:6px;margin-bottom:8px">
    <select id="ek-stok-sel" class="fsel" style="flex:1">
      <option value="">Stoktan seç…</option>
    </select>
    <input id="ek-doz" class="fi" type="number" step="0.5" min="0.5" placeholder="Doz" style="width:70px">
    <select id="ek-yol" class="fsel" style="width:80px">
      <option value="IM">IM</option>
      <option value="SC">SC</option>
      <option value="IV">IV</option>
    </select>
    <button type="button" onclick="ekUygulamaEkle()" style="padding:6px 10px;background:var(--blue);color:#fff;border:none;border-radius:8px;font-weight:700;cursor:pointer">+</button>
  </div>

  <!-- Eklenen item'ler listesi -->
  <div id="ek-liste" style="display:none">
    <!-- JS tarafından doldurulacak -->
  </div>
</div>

<!-- SORUN TESPİT TOGGLE -->
<div class="fg" style="display:flex;align-items:center;justify-content:space-between;background:rgba(192,50,26,.06);border:1px solid rgba(192,50,26,.15);border-radius:10px;padding:10px">
  <span style="font-size:.78rem;font-weight:600;color:var(--ink2)">⚠️ Muayenede sorun tespit edildi</span>
  <label style="position:relative;display:inline-block;width:40px;height:22px">
    <input type="checkbox" id="i-sorun-toggle" onchange="sorunToggle(this)" style="opacity:0;width:0;height:0">
    <span id="i-sorun-thumb" style="position:absolute;inset:0;background:var(--card3);border-radius:11px;cursor:pointer;transition:.2s"></span>
  </label>
</div>
```

Chip'ler için global CSS (index.html `<style>` bloğuna ekle):
```css
.ek-chip{padding:4px 10px;border-radius:20px;border:1px solid var(--card3);background:var(--card);color:var(--ink2);font-size:.7rem;font-weight:600;cursor:pointer;transition:.15s}
.ek-chip.aktif{background:var(--blue);color:#fff;border-color:var(--blue)}
```

---

## Task 2 + Task 3 — Paralel Çalıştır

> Bağımsız task'lar — dosya sahipliği ayrı.
> Task 2 → `js/forms.js` | Task 3 → `js/ui.js`

---

### Task 2 — forms.js: Ek Uygulama JS Fonksiyonları + submitInsem Güncelleme

**Eklenecek global state ve fonksiyonlar** (forms.js'e, submitInsem'den önce):

```js
// Ek uygulama state
let _ekUygulamalar = [];
let _ekSeciliTur = null;

function ekChipSec(btn) {
  _ekSeciliTur = btn.dataset.tur;
  document.querySelectorAll('.ek-chip').forEach(b => b.classList.remove('aktif'));
  btn.classList.add('aktif');
  document.getElementById('ek-stok-row').style.display = 'flex';
  // Stok dropdown'ı filtrele (tur'a göre)
  _ekStokYukle(_ekSeciliTur);
}

async function _ekStokYukle(tur) {
  const tum = await idbGetAll('stok');
  const sel = document.getElementById('ek-stok-sel');
  // Kategori eşleştirme — stok kategorisi ile chip türünü eşleştir
  // Başlamadan Önce adımında gördüğün kategori adlarını kullan
  const esTablo = {
    'GnRH': ['Hormon', 'GnRH'],
    'PG': ['Hormon', 'PG', 'Prostaglandin'],
    'E Vitamini': ['Vitamin', 'E Vitamini'],
    'B12': ['Vitamin', 'B12'],
    'Selenium': ['Vitamin', 'Mineral', 'Selenium'],
    'Diğer': null  // tümünü göster
  };
  const kategoriler = esTablo[tur] || null;
  const filtreli = kategoriler
    ? tum.filter(s => kategoriler.some(k => (s.kategori||'').toLowerCase().includes(k.toLowerCase())))
    : tum;
  sel.innerHTML = '<option value="">Stoktan seç…</option>' +
    filtreli.map(s => `<option value="${s.id}" data-ad="${esc(s.urun_adi)}" data-birim="${s.birim||'adet'}">${esc(s.urun_adi)} (${s.miktar||0} ${s.birim||'adet'})</option>`).join('');
}

function ekUygulamaEkle() {
  const sel = document.getElementById('ek-stok-sel');
  const doz = parseFloat(document.getElementById('ek-doz').value) || 0;
  const yol = document.getElementById('ek-yol').value;
  const stokId = sel.value;
  const stokAd = sel.options[sel.selectedIndex]?.dataset?.ad || '';
  const birim = sel.options[sel.selectedIndex]?.dataset?.birim || 'ml';

  if (!_ekSeciliTur) { toast('Uygulama türü seçin', true); return; }
  if (doz <= 0) { toast('Doz girin', true); return; }

  _ekUygulamalar.push({ tur: _ekSeciliTur, stok_id: stokId, stok_ad: stokAd, doz, birim, yol });
  _ekListeGoster();

  // Reset
  document.getElementById('ek-doz').value = '';
  document.querySelectorAll('.ek-chip').forEach(b => b.classList.remove('aktif'));
  document.getElementById('ek-stok-row').style.display = 'none';
  _ekSeciliTur = null;
}

function ekUygulama_sil(idx) {
  _ekUygulamalar.splice(idx, 1);
  _ekListeGoster();
}

function _ekListeGoster() {
  const el = document.getElementById('ek-liste');
  if (!_ekUygulamalar.length) { el.style.display = 'none'; return; }
  el.style.display = 'block';
  el.innerHTML = _ekUygulamalar.map((u, i) =>
    `<div style="display:flex;justify-content:space-between;align-items:center;padding:4px 0;border-bottom:1px solid var(--card3);font-size:.75rem">
      <span><b>${esc(u.tur)}</b> ${u.stok_ad ? '– ' + esc(u.stok_ad) : ''} · ${u.doz} ${u.birim} · ${u.yol}</span>
      <button type="button" onclick="ekUygulama_sil(${i})" style="background:none;border:none;color:var(--red2);cursor:pointer;font-size:.85rem">🗑</button>
    </div>`
  ).join('');
}
```

**submitInsem güncellemesi** — RPC çağrısına `p_ek_uygulamalar` parametresi ekle:

```js
// Mevcut submitInsem içinde rpc('tohumlama_kaydet', {...}) çağrısına ekle:
p_ek_uygulamalar: JSON.stringify(_ekUygulamalar)

// Modal kapanınca state sıfırla (closeM sonrası):
_ekUygulamalar = [];
_ekListeGoster();
```

**Sorun toggle fonksiyonu** (forms.js sonuna ekle):

```js
function sorunToggle(cb) {
  const thumb = document.getElementById('i-sorun-thumb');
  thumb.style.background = cb.checked ? 'var(--red2)' : 'var(--card3)';
  // globalThis._sorunToggle state — Plan-E'de kullanılacak
  globalThis._insemSorunVar = cb.checked;
}
```

**Syntax kontrolü:**
```bash
node --check /root/egesut-erp1/js/forms.js
```

---

### Task 3 — ui.js: Kızgınlık Kart Güncellemesi

**Okuma:**
```bash
sed -n '1316,1351p' /root/egesut-erp1/js/ui.js
```

**Uygulama:**

`_uremeKizginlik` içindeki `card()` fonksiyonunu güncelle:

1. **POSTPARTUM_GOZLEM badge** (aktif kızgınlıklar için) — Plan-A'da zaten yapıldı, kontrol et.

2. **Bağlı case göstergesi** — `hist-sub` satırına ekle:
```js
const caseBadge = k.tedavi_case_id && !cozulduMi
  ? `<span style="font-size:.6rem;color:var(--blue);background:rgba(42,107,181,.1);border-radius:4px;padding:1px 5px;margin-left:4px;cursor:pointer" onclick="event.stopPropagation();openCaseById('${k.tedavi_case_id}')">🔗 Vaka</span>`
  : '';
// hist-sub satırına ekle: `${esc(k.tarih)} ${k.notlar?'· '+esc(k.notlar):''} ${caseBadge}`
```

**Syntax kontrolü:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

---

## Task 4 — Commit

Her iki dosya syntax kontrolünden geçtikten sonra:

```bash
git add index.html js/forms.js js/ui.js
git commit -m "feat(ui): tohumlama ek uygulama bölümü + sorun toggle + kızgınlık kart case bağlantı"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "Plan-D tamamlandı: tohumlama modalına ek uygulama chip+stok+doz+yol bölümü eklendi, _ekUygulamalar state array, submitInsem p_ek_uygulamalar ile RPC'ye gönderir. Kızgınlık kartı case bağlantı badge ve POSTPARTUM_GOZLEM badge gösteriyor.",
  category: "code_change",
  priority: "medium",
  tags: "ui,tohumlama,kizginlik,ek_uygulama,forms"
})
```
