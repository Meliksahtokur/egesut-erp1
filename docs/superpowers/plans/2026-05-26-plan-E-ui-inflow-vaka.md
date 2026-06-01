# UI — In-Flow Vaka Açma (Tohumlama → Pre-fill Tedavi) — Plan E

> Topoloji: Hierarchical | 3 task | 0 paralel blok
> Model: deepseek-chat (flash)
> Soru varsa devam etmeden önce sor. JS değişikliklerinde node --check zorunlu.

**Hedef:** Tohumlama kaydedildikten sonra "Sorun var" toggle açıksa, bir bottom sheet kayar. Kullanıcı sorun türünü seçer → `kizginlik_vaka_ac` RPC çağrılır → tedavi/vaka ekranı bu bilgilerle açılır. Modal geçişi olmadan, aynı akış içinde.

**Etkilenen dosyalar:**
- `js/forms.js` → submitInsem sonrası akış
- `js/ui.js` → vaka açma bottom sheet render + pre-fill

**Bağımlılık:** Plan-B (kizginlik_vaka_ac RPC) + Plan-D (sorunToggle state) tamamlanmış olmalı.

---

## Başlamadan Önce

Sırayla oku:
```bash
# 1. submitInsem fonksiyonunun tamamı (Plan-D sonrası güncel hali)
grep -n "async function submitInsem" /root/egesut-erp1/js/forms.js
# Satır bul → fonksiyonu oku

# 2. Vaka açma akışı — mevcut modal veya akış
grep -n "openM.*disease\|m-disease\|loadDiseasesDropdown\|submitVaka\|submitDisease" \
  /root/egesut-erp1/js/forms.js | head -10
grep -n "m-disease\|m-hastalik\|m-vaka" /root/egesut-erp1/index.html | head -5

# 3. kizginlik_tedavi_baglanti_kur ve kizginlik_vaka_ac RPC imzası
cat /root/egesut-erp1/.claude/rpc-reference.md | grep -A3 "kizginlik_vaka_ac\|kizginlik_tedavi_baglanti"

# 4. globalThis._kizginlikTedaviId pattern (mevcut bağlantı akışı)
grep -n "_kizginlikTedaviId" /root/egesut-erp1/js/forms.js
grep -n "_kizginlikTedaviId" /root/egesut-erp1/js/ui.js
```

Mevcut `_kizginlikTedaviId` pattern'ini anladıktan sonra devam et — aynı pattern'i extend edeceğiz.

---

## Task 1 — submitInsem Sonrası Akış: Sorun Varsa Bottom Sheet

**Uygulama:**

`submitInsem` fonksiyonunda başarılı kayıt sonrası (`toast('✅ Tohumlama kaydedildi')` satırından sonra):

```js
// Başarılı kayıt sonrası:
toast('✅ Tohumlama kaydedildi');

// Sorun toggle açıksa bottom sheet aç
if (globalThis._insemSorunVar) {
  // Kapanmadan önce tohumlama id'sini sakla
  // RPC dönüşünden tohumlama_id alınıyorsa sakla; yoksa null gönder
  const tohId = result?.tohumlama_id || null;
  // Aktif kızgınlık id'si — eğer kızgınlık listesinden tohumlama açıldıysa globalThis'te saklanıyor mu kontrol et
  const kizId = globalThis._insemKizginlikId || null;

  // Modal'ı kapat ama state'i sıfırlama — bottom sheet geldikten sonra sıfırlayacağız
  closeM('m-insem');
  setTimeout(() => sorunBottomSheet(tohId, kizId), 200);
} else {
  closeM('m-insem');
  globalThis._insemSorunVar = false;
  globalThis._insemKizginlikId = null;
}
```

**Kızgınlık → Tohumlama bağlantısı için:** `openInsemSafe` fonksiyonunun kızgınlık id'sini `globalThis._insemKizginlikId`'ye yazması gerekiyor. `openInsemSafe` fonksiyonunu oku ve `globalThis._insemKizginlikId = kizginlik.id` satırı ekle (kızgınlık listesindeki "💉 Tohumla" butonu burayı çağırıyor).

**Syntax kontrolü:**
```bash
node --check /root/egesut-erp1/js/forms.js
```

---

## Task 2 — sorunBottomSheet Fonksiyonu (ui.js)

**Uygulama:**

`ui.js`'e yeni fonksiyon ekle (global scope, `_uremeKizginlik`'ten önce veya sonra):

```js
function sorunBottomSheet(tohId, kizId) {
  let box = document.getElementById('sorun-bs');
  if (box) box.remove();

  const sorunlar = [
    { id: 'endometrit',  label: '🦠 Endometrit',    tani: 'Endometrit' },
    { id: 'kist',        label: '🔵 Kist',           tani: 'Over Kisti' },
    { id: 'tumor',       label: '🎗 Tümör',          tani: 'Tümör' },
    { id: 'pg',          label: '💊 PG Protokolü',   tani: 'PG Protokolü' },
    { id: 'prit',        label: '💉 PRIT',            tani: 'PRIT Protokolü' },
    { id: 'diger',       label: '+ Serbest Giriş',   tani: null },
  ];

  box = document.createElement('div');
  box.id = 'sorun-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) { box.remove(); _sorunBsTemizle(); } };

  box.innerHTML = `
    <div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.95rem;margin-bottom:4px">⚠️ Tespit edilen sorunu seçin</div>
      <div style="font-size:.75rem;color:var(--ink3);margin-bottom:14px">Tohumlama kaydedildi — şimdi vaka açılıyor</div>
      <div style="display:flex;flex-wrap:wrap;gap:7px;margin-bottom:14px">
        ${sorunlar.map(s => `
          <button type="button" onclick="sorunSec('${s.id}','${esc(s.tani||'')}',event)"
            style="padding:7px 13px;border-radius:20px;border:1.5px solid var(--card3);background:var(--card);color:var(--ink2);font-size:.78rem;font-weight:600;cursor:pointer">
            ${s.label}
          </button>`).join('')}
      </div>
      <div id="sorun-serbest" style="display:none;margin-bottom:12px">
        <input id="sorun-serbest-input" class="fi" placeholder="Tanı / notlar…">
      </div>
      <div style="display:flex;gap:8px">
        <button onclick="sorunVakaAc('${tohId||''}','${kizId||''}')"
          style="flex:1;padding:12px;background:var(--red2);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">
          🏥 Vaka Aç
        </button>
        <button onclick="document.getElementById('sorun-bs').remove();_sorunBsTemizle()"
          style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;cursor:pointer">
          Şimdi Değil
        </button>
      </div>
    </div>`;
  document.body.appendChild(box);
}

let _sorunSecilen = null;

function sorunSec(id, tani, e) {
  _sorunSecilen = { id, tani };
  document.querySelectorAll('#sorun-bs button[onclick^="sorunSec"]').forEach(b => {
    b.style.background = 'var(--card)';
    b.style.borderColor = 'var(--card3)';
    b.style.color = 'var(--ink2)';
  });
  e.target.style.background = 'var(--red2)';
  e.target.style.borderColor = 'var(--red2)';
  e.target.style.color = '#fff';
  // Serbest giriş alanı
  const serbest = document.getElementById('sorun-serbest');
  if (id === 'diger') serbest.style.display = 'block';
  else serbest.style.display = 'none';
}

async function sorunVakaAc(tohId, kizId) {
  if (!_sorunSecilen) { toast('Sorun türü seçin', true); return; }
  let tani = _sorunSecilen.id === 'diger'
    ? (document.getElementById('sorun-serbest-input')?.value?.trim() || 'Bilinmiyor')
    : _sorunSecilen.tani;

  try {
    let caseId;
    if (kizId) {
      // kizginlik_vaka_ac RPC — kızgınlık + tohumlama + case üçlü bağlantı
      const res = await rpc('kizginlik_vaka_ac', {
        p_kizginlik_id: kizId,
        p_tani: tani,
        p_tohumlama_id: tohId || null,
        p_notlar: 'Tohumlama sırasında tespit edildi'
      });
      caseId = res?.case_id;
    } else {
      // Kızgınlık id'si yoksa doğrudan vaka açma modalına yönlendir
      // mevcut hastalık/vaka akışını pre-fill ile aç
      _sorunPreFill = { tani, kategori: 'Üreme', notlar: 'Tohumlama sırasında tespit edildi' };
      document.getElementById('sorun-bs')?.remove();
      _sorunBsTemizle();
      openM('m-disease');
      return;
    }

    document.getElementById('sorun-bs')?.remove();
    _sorunBsTemizle();
    toast('🏥 Vaka açıldı');

    await pullTables(['cases','kizginlik_log','tohumlama']);
    renderSafe();

    // Açılan vakaya doğrudan git (opsiyonel)
    if (caseId) {
      setTimeout(() => {
        if (typeof openCaseById === 'function') openCaseById(caseId);
      }, 400);
    }
  } catch(e) { toast('❌ ' + e.message, true); }
}

function _sorunBsTemizle() {
  _sorunSecilen = null;
  globalThis._insemSorunVar = false;
  globalThis._insemKizginlikId = null;
}
```

**Syntax kontrolü:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

---

## Task 3 — openInsemSafe Güncelle + Commit

**Okuma:**
```bash
grep -n "openInsemSafe\|function openInsemSafe" /root/egesut-erp1/js/ui.js
# Satır bul → fonksiyonu oku
```

**Uygulama:**

`openInsemSafe` fonksiyonu kızgınlık listesindeki "💉 Tohumla" butonu ile tetikleniyorsa, kızgınlık id'sini state'e yaz. Butonun bulunduğu yerde (`_uremeKizginlik` card render):

```js
// "💉 Tohumla" buton onclick'ine kizginlik id'si ekle:
onclick="event.stopPropagation();globalThis._insemKizginlikId='${k.id}';openInsemSafe('${kupe}')"
```

**Commit:**
```bash
git add js/forms.js js/ui.js
git commit -m "feat(ui): tohumlama sonrası in-flow vaka açma — sorunBottomSheet, kizginlik_vaka_ac pre-fill"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "Plan-E tamamlandı: submitInsem sonrası _insemSorunVar=true ise sorunBottomSheet açılıyor. Kullanıcı sorun seçer → kizginlik_vaka_ac RPC → case açılır, openCaseById ile case ekranına yönlendirme. _insemKizginlikId state'i kızgınlık listesindeki Tohumla butonundan set ediliyor.",
  category: "code_change",
  priority: "medium",
  tags: "ui,tohumlama,vaka,bottom-sheet,kizginlik,inflow"
})
```
