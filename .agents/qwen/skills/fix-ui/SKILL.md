---
name: fix-ui
description: UI bug düzeltme — Systematic approach to fixing UI bugs in EgeSüt ERP
version: 2.0.1
session: dev
---

# Fix UI Bug Skill

## 🗣️ Dil Kuralı (KRİTİK)

**ANADİL: TÜRKÇE**

- ✅ Tüm yorumlar, commit mesajları **Türkçe**
- ✅ Console/toast mesajları **Türkçe**
- ❌ Kullanıcı istemedikçe İngilizce kullanma

---

## 🎯 Ne Zaman Kullanılır

**Bu skill SADECE `dev` session'da aktif olur.**

- UI butonları çalışmıyor
- Modal açılmıyor/kapanmıyor
- Form validasyonu hatalı
- Tablo/render sorunu
- CSS layout bozuk
- Console'da JS hatası var

## ⚠️ Session Kilidi

**Bu skill ERP UI bug fix içindir. Arge işi YASAK.**

❌ Skill/agent/MCP geliştirme → `gwen-arge` kullan
❌ `.qwen/` dizininde değişiklik → `gwen-arge` kullan

---

## 🛠️ Workflow (4 Adım)

### 1️⃣ Bug'ı Tekrar Oluştur

```
1. Uygulamayı tarayıcıda aç (index.html)
2. Bug'ı tetikleyen adımları uygula
3. Şunları not et:
   - Hangi sayfa/component etkilenmiş?
   - Hangi kullanıcı aksiyonu sorunu tetikliyor?
   - Beklenen davranış vs gerçekleşen davranış
   - Console'da hata var mı? (F12 → Console)
```

### 2️⃣ Kök Nedeni Bul

```bash
# Browser DevTools aç (F12)
# Etkilenen elementi incele

# Kontrol listesi:
- [ ] CSS sorunları (yanlış class, eksik style, specificity çakışması)
- [ ] JavaScript hataları (console'da kırmızı hata)
- [ ] Network hataları (başarısız API çağrıları)
- [ ] DOM yapısı problemleri

# Codebase'de ara:
grep -r "etkilenen-fonksiyon" js/
```

**EgeSüt ERP Özel:**
```bash
# UI dosyalarını kontrol et
grep -n "fonksiyonAdi" js/ui.js
grep -n "fonksiyonAdi" js/forms.js
grep -n "fonksiyonAdi" js/app.js
```

### 3️⃣ Düzeltmeyi Uygula

```
1. İlgili dosyayı düzenle (js/ui.js, js/forms.js, css/styles.css)
2. Proje konvansiyonlarına uy:
   - camelCase fonksiyon adları
   - Türkçe yorum satırları
   - Türkçe toast/error mesajları
3. Syntax kontrolü:
   node --check js/dosya.js
4. Duplikat kontrolü:
   grep -n "function fonksiyonAdi" js/*.js
```

**Örnek Düzeltme:**
```javascript
// ❌ YANLIŞ - Modal kapanmıyor
async function tohumlamaKaydet() {
  await supabase.rpc('tohumlama_kaydet', {...});
  // closeModal eksik!
}

// ✅ DOĞRU - Modal kapanıyor
async function tohumlamaKaydet() {
  const { error } = await supabase.rpc('tohumlama_kaydet', {...});
  if (error) {
    showToast('Hata: ' + error.message, 'error');
    return;
  }
  showToast('Tohumlama kaydedildi!', 'success');
  closeModal(); // ✅ Modal kapat
  renderTohumlamaListesi(); // ✅ Listeyi yenile
}
```

### 4️⃣ Düzeltmeyi Doğrula

```bash
# 1. Sayfayı yenile (Ctrl+R veya Cmd+R)
# 2. Bug'ı tekrar oluştur (Adım 1'deki adımlar)
# 3. Kontrol et:
- [ ] ✅ Bug artık oluşmuyor
- [ ] ✅ Beklenen davranış gösteriliyor
- [ ] ✅ Console'da yeni hata yok
- [ ] ✅ İlgili feature'larda regresyon yok

# 4. Başarılı ise commit:
git add js/
git commit -m "DONE: dev — [bug özeti]"
```

---

## 📋 Checklist

Her UI bug fix için:

```
[ ] Bug tekrar oluşturuldu ve dokümante edildi
[ ] Root cause bulundu (CSS/JS/DOM/API)
[ ] Düzeltme uygulandı (syntax doğru)
[ ] node --check geçti
[ ] Duplikat fonksiyon yok
[ ] Tarayıcıda test edildi
[ ] Regresyon yok
[ ] Türkçe mesajlar kullanıldı
[ ] DONE: commit mesajı açıklayıcı
```

---

## 🚨 Sık Yapılan Hatalar

| Hata | Çözüm |
|---|---|
| **Modal kapanmıyor** | `closeModal()` çağrısını unutma |
| **Liste güncellenmiyor** | `render*()` fonksiyonunu çağır |
| **Toast gösterilmiyor** | `showToast()` import edilmiş mi kontrol et |
| **Buton çalışmıyor** | Event listener eklenmiş mi? |
| **Form submit olmuyor** | `event.preventDefault()` var mı? |
| **API hatası** | RPC adı doğru mu? Parametreler tam mı? |

---

## 🔧 EgeSüt ERP UI Dosyaları

| Dosya | Sorumluluk | Satır |
|---|---|---|
| `js/ui.js` | DOM render, modal, autocomplete | ~2800 |
| `js/forms.js` | Form submit, validasyon, RPC | ~940 |
| `js/app.js` | App init, routing, IndexedDB | ~740 |
| `js/api.js` | Supabase client, RPC wrapper | ~330 |
| `js/state.js` | Global state (getState, setState) | ~50 |
| `js/config.js` | Domain sabitleri (GRUP_PADOK) | ~100 |

---

## 📖 Referanslar

- **Domain Kuralları:** `.claude/domain-rules.md`
- **RPC İmzaları:** `.claude/rpc-reference.md`
- **UI Haritası:** `.claude/ui-map.md`
- **Session Kuralları:** `.qwen/QWEN.md`

---

**Bu skill yüklendiğinde:** UI bug fix workflow'u otomatik aktif olur.

🔧 Fix UI hazır!
