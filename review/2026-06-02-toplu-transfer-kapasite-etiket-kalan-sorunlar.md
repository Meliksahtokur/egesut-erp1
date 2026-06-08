# Kalan Sorunlar — Plan v2 (62995da6)

> **Plan:** `docs/superpowers/plans/2026-06-02-toplu-transfer-kapasite-etiket.md`
> **Spec:** `docs/superpowers/specs/2026-06-02-toplu-transfer-kapasite-etiket.md`
> **Doğrulama:** tools-bank MCP + direct code analysis
> **Durum:** ❌ 1 kritik + 1 minör sorun kaldı

---

## 🔴 KRİTİK: `bulkTabSwitch` ID Uyuşmazlığı

### Sorun

Plan (line 887), `btTabSwitch` yazmak yerine mevcut `bulkTabSwitch(prefix, tab)` fonksiyonunu (`forms.js:1547`) yeniden kullanmayı hedefliyor. Handler kayıtları (line 1377) doğru çağırıyor:

```javascript
'bt-tab-padok':    () => bulkTabSwitch('bt', 'padok'),
'bt-tab-filtre':   () => bulkTabSwitch('bt', 'filtre'),
'bt-tab-serbest':  () => bulkTabSwitch('bt', 'serbest'),
```

**Ancak** plan'daki HTML ID'leri ve class'ları `bulkTabSwitch`'in beklediği kalıpla uyuşmuyor.

### Mevcut `bulkTabSwitch` fonksiyonu (`forms.js:1547-1563`)

```javascript
function bulkTabSwitch(prefix, tab) {
  ['padok','filtre','serbest'].forEach(t => {
    const sec  = document.getElementById(prefix + '-section-' + t);  // bt-section-*
    const btn  = document.getElementById(prefix + '-tab-' + t);      // bt-tab-*
    if (sec) sec.style.display = t === tab ? '' : 'none';
    if (btn) {
      btn.style.opacity  = t === tab ? '1' : '0.5';
      btn.className      = t === tab ? 'btn btn-g' : 'btn btn-o';
    }
  });
  if (tab === 'serbest') loadBulkSerbest(prefix);
}
```

### Plan'daki HTML (line 327-376) vs Beklenen

| Element | Plan HTML ID | `bulkTabSwitch` bekler | Uyum |
|---------|-------------|------------------------|------|
| Panel (Padok) | `bt-tab-padok` | `bt-section-padok` | ❌ |
| Panel (Filtre) | `bt-tab-filtre` | `bt-section-filtre` | ❌ |
| Panel (Serbest) | `bt-tab-serbest` | `bt-section-serbest` | ❌ |
| Buton (Padok) | `bt-tab-btn-padok` | `bt-tab-padok` | ❌ |
| Buton (Filtre) | `bt-tab-btn-filtre` | `bt-tab-filtre` | ❌ |
| Buton (Serbest) | `bt-tab-btn-serbest` | `bt-tab-serbest` | ❌ |
| Panel class | `tab-panel on` / `tab-panel` | `style="display:none"` / `style=""` | ❌ |
| Button class | `tab-btn on` / `tab-btn` | `btn btn-g` / `btn btn-o` | ❌ |
| CSS | `.tab-panel{display:none} .tab-panel.on{display:block} .tab-btn{...} .tab-btn.on{...}` | Yok (inline style + class) | ❌ |

### Mevcut bulk modal'lar doğru kalıbı kullanıyor

**`m-bulk-vaccine` (index.html:854-903):**
```html
<button id="bv-tab-padok" class="btn btn-g" ...>Padok</button>
<button id="bv-tab-filtre" class="btn btn-o" ...>Filtre</button>
<button id="bv-tab-serbest" class="btn btn-o" ...>Serbest Seçim</button>

<div id="bv-section-padok">...</div>
<div id="bv-section-filtre" style="display:none">...</div>
<div id="bv-section-serbest" style="display:none">...</div>
```

### Çözüm — HTML ID/class'larını bulunulan pattern'a çevir

Plan'daki HTML (line 327-376) şu hale getirilmeli:

```html
<!-- Tab butonları -->
<div style="display:flex;gap:4px;margin-bottom:12px;overflow-x:auto">
  <button class="btn btn-g" id="bt-tab-padok" data-action="bt-tab-padok">📋 Padok</button>
  <button class="btn btn-o" id="bt-tab-filtre" data-action="bt-tab-filtre">🎯 Filtre</button>
  <button class="btn btn-o" id="bt-tab-serbest" data-action="bt-tab-serbest">✋ Serbest</button>
</div>

<!-- Tab: Padok -->
<div id="bt-section-padok">
  ...
</div>

<!-- Tab: Filtre -->
<div id="bt-section-filtre" style="display:none">
  ...
</div>

<!-- Tab: Serbest -->
<div id="bt-section-serbest" style="display:none">
  ...
</div>
```

Ayrıca plan'daki Task 3 Step 6'da tanımlanan CSS'ten `.tab-panel`, `.tab-panel.on`, `.tab-btn`, `.tab-btn.on` kuralları **kaldırılabilir** (artık kullanılmayacak).

---

## ⚠️ MİNÖR: Note 2 vs Note 11 Çelişkisi

### Sorun

Plan'ın `## Notlar DeepSeek İçin` bölümünde iki not birbiriyle çelişiyor:

**Note 2 (line 1437):**
```
2. **`window._padoklar` YOK** — `loadPadokConfig()` içinde padoklar yüklenince
   `window._padoklar = padoklar` ile set et. Sonrasında tüm `window._padoklar`
   kullanımları çalışır.
```

**Note 11 (line 1464):**
```
11. **`PADOKLAR` ve `GRUP_PADOK` import** — `js/ui.js` satır 13'te her ikisi de
    config.js'den import edilmiş. `window.PADOKLAR`, `window.GRUP_PADOK`,
    `window._padoklar` gibi global erişim kullanma.
```

- Note 2: `window._padoklar` **OLUŞTUR** diyor
- Note 11: `window._padoklar` **KULLANMA** diyor

### Çözüm

Note 2 güncellenmeli — `PADOKLAR` direkt kullanıldığı için `window._padoklar` oluşturmaya gerek yok:

```
2. **`PADOKLAR` kullan** — `js/config.js:60`'ta tanımlı (`let PADOKLAR = []`).
   `loadPadokConfig()` içinde `PADOKLAR = padoklar` ile doldurulur.
   ui.js satır 13'te `/* global PADOKLAR */` ile bildirilmiştir.
   `window._padoklar` gibi yeni bir global **oluşturma**.
```

---

## ✅ Plan'da Doğru Olan (Önceki review'den düzelenler)

| Sorun | Durum |
|-------|-------|
| `islem_log` kolon isimleri (`tip`, `ana_hayvan_id`, `snapshot`, etc.) | ✅ Notlarda düzeltilmiş |
| `updated_at = now()` | ✅ Notlarda eklenmiş |
| `loadSuru()` → `loadAnimals()` | ✅ Notlarda düzeltilmiş |
| `window._suruData` → `getState('animals')` | ✅ Plan gövdesinde düzeltilmiş |
| `window._padoklar` → `PADOKLAR` | ✅ Plan gövdesinde düzeltilmiş |
| `window.GRUP_PADOK` → `GRUP_DIREKT` | ✅ Plan gövdesinde düzeltilmiş |
| Animal card line 629 (`data-id` + checkbox) | ✅ Plan gövdesinde düzeltilmiş |
| `padoklar.kapasite` NULL notu | ✅ Eklenmiş |
| `ground_truth.sql` satır numaraları | ✅ Doğrulanmış |
| `m-padok-transfer` satırı (`1782` → `1797`) | ✅ Güncellenmiş |

---

## Özet

| # | Sorun | Seviye | Etki |
|---|-------|--------|------|
| 1 | `bulkTabSwitch` ID uyuşmazlığı — HTML `bt-tab-*`/`bt-tab-btn-*`/`tab-btn` class, fonksiyon `bt-section-*`/`bt-tab-*`/`btn btn-g` bekliyor | 🔴 KRİTİK | Implementasyonda tab butonları çalışmaz |
| 2 | Note 2 vs Note 11 çelişkisi — `window._padoklar` oluştur/kullanma | ⚠️ MİNÖR | Kafa karışıklığı, kod çalışır |

---

*Son güncelleme: 2026-06-02*
