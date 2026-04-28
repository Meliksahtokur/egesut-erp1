# Güvenlik Analizi — forms.js

**Analiz Tarihi:** 2025-07-14  
**Dosya:** `/root/egesut-erp1/js/forms.js`  
**Analist:** WORKER_SECURITY_2

---

## Özet

| Kategori | Bulgu Sayısı |
|---|---|
| Input Validation | 5 |
| XSS Vulnerabilities | 3 |
| Data Sanitization | 4 |
| Error Message Exposure | 2 |
| Authentication Issues | 1 |

---

## 1. Input Validation

### Bulgu #1 — Zayıf Doğum Tarihi Kontrolü
- **Öncelik:** ORTA
- **Dosya ve Satır:** forms.js:41-42
- **Sorun:** Doğum tarihi negatif yaş kontrolü yapılıyor ama üst sınır kontrolü eksik. Yaşı 50 yıl olan bir hayvan girilebilir.
- **Çözüm önerisi:**
```javascript
const _yasGun = Math.floor((Date.now() - new Date(_dt)) / 86400000);
if (_yasGun < 0) { toast('...'); return; }
if (_yasGun > 365 * 25) { toast('⚠️ Geçersiz yaş', true); return; } // Max ~25 yıl
```

---

### Bulgu #2 — Sayısal Alanlarda NaN/Infinity Kontrolü Eksik
- **Öncelik:** YUKSEK
- **Dosya ve Satır:** forms.js:62-65
- **Sorun:** `Number.parseFloat()` kullanılıyor ama NaN veya Infinity kontrolü yok. Boş string `parseFloat('')` → NaN döner, backend'e gönderilir.
- **Çözüm önerisi:**
```javascript
p_dogum_kg: (() => {
  const v = Number.parseFloat(v('a-dkg'));
  return (isNaN(v) || !isFinite(v)) ? null : v;
})(),
```

---

### Bulgu #3 — ID ile Lookup'da Tür Dönüşümü Kontrolü
- **Öncelik:** ORTA
- **Dosya ve Satır:** forms.js:106, 128, 147, 195, 229
- **Sorun:** `getState('animals').find(a => a.id === hid || a.kupe_no === hid || a.devlet_kupe === hid)` — `hid` string olarak geliyor ama `id` UUID olabilir. Tür uyumsuzluğunda arama başarısız olur.
- **Çözüm önerisi:** UUID validation ekle veya tipi normalize et:
```javascript
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUUID = UUID_REGEX.test(hid);
const hayvan = getState('animals').find(a =>
  isUUID ? a.id === hid : (a.kupe_no === hid || a.devlet_kupe === hid)
);
```

---

### Bulgu #4 — Negatif Stok Miktarı Kontrolü Eksik
- **Öncelik:** YUKSEK
- **Dosya ve Satır:** forms.js:475
- **Sorun:** `submitStk` sadece `mik > 0` kontrolü yapıyor ama `submitStokAdd` ve `submitSuttenKes` PATCH işlemlerinde miktar ekleme/çıkarma validation'ı yetersiz.
- **Çözüm önerisi:** PATCH sonrası stok değerini doğrula ve negatif olamayacağını kontrol et.

---

### Bulgu #5 — gebelik_ekle'de Sonuç Değeri Hardcoded
- **Öncelik:** DUSUK
- **Dosya ve Satır:** forms.js:579
- **Sorun:** `sonuc: 'Gebe'` doğrudan kodda yazılmış. Yanlışlıkla başka bir sonuç değeri gönderilirse veri tutarsızlığı oluşur.
- **Çözüm önerisi:** Sabit enum kullan veya RPC ile gebelik kaydet.

---

## 2. XSS Vulnerabilities

### Bulgu #6 — innerHTML ile Kullanıcı Verisi Render Etme
- **Öncelik:** KRITIK
- **Dosya ve Satır:** forms.js:324-337 (`gebeIsaretle`)
- **Sorun:** `box.innerHTML` içinde `t.sperma`, `t.tarih` gibi kullanıcı verisi doğrudan inject ediliyor. Kızgınlık/sperma notları `<script>` tag içerebilir.
```javascript
return `<label>...
  <div style="font-size:.7rem;color:var(--ink3)">${t.sperma || '?'} · ${t.tarih}...</div>
</label>`;
```
- **Çözüm önerisi:** `textContent` kullan veya DOMPurify ile sanitize et:
```javascript
const div = document.createElement('div');
div.textContent = t.sperma || '?';
```

---

### Bulgu #7 — innerHTML İçinde Dinamik Semptom Değerleri
- **Öncelik:** KRITIK
- **Dosya ve Satır:** forms.js:311-316
- **Sorun:** `chip.innerHTML` ile semptom adı doğrudan inject ediliyor:
```javascript
chip.innerHTML = `${val} <span onclick="semptomKaldir('${val}',this.parentElement)">✕</span>`;
```
- **Çözüm önerisi:**
```javascript
chip.textContent = val;
const span = document.createElement('span');
span.textContent = '✕';
span.onclick = () => semptomKaldir(val, chip);
chip.appendChild(span);
```

---

### Bulgu #8 — Aşı Bilgi/Hint InnerHTML Kullanımı
- **Öncelik:** ORTA
- **Dosya ve Satır:** forms.js:380, 384
- **Sorun:** `hint.innerHTML = '... ${vax.repeat_interval_days} ...'` — aşı adı ve açıklaması database'den geliyor, XSS riski.
- **Çözüm önerisi:** `hint.textContent` kullan veya sadece sayısal değerleri template'e koy.

---

## 3. Data Sanitization

### Bulgu #9 — Global DOM Fonksiyonu ile Inline Event Handler
- **Öncelik:** YUKSEK
- **Dosya ve Satır:** forms.js:325, 333
- **Sorun:** `onclick` attribute'u dinamik HTML içinde kullanılıyor. Event handler fonksiyonu global scope'da olmalı ve fonksiyon ismi string olarak güvenli.
```javascript
box.onclick = e => { if (e.target === box) box.remove(); };
```
- **Çözüm önerisi:** DOM elemanları oluşturup `addEventListener` kullan.

---

### Bulgu #10 — Semptom Kaldırma Fonksiyonu Inline String Eval
- **Öncelik:** YUKSEK
- **Dosya ve Satır:** forms.js:312
- **Sorun:** `onclick="semptomKaldir('${val}',this.parentElement)"` — val değeri apostrof içeriyorsa `semptomKaldir('O\'Brien', ...)` syntax hatası oluşur.
- **Çözüm önerisi:** Val değerini JavaScript string olarak değil, data attribute olarak taşı:
```javascript
chip.dataset.val = val;
span.onclick = (e) => semptomKaldir(chip.dataset.val, chip);
```

---

### Bulgu #11 — openNotModal'da Kupe Parametresi Direct DOM Set
- **Öncelik:** ORTA
- **Dosya ve Satır:** forms.js:163
- **Sorun:** `textContent` kullanılıyor — bu doğru. Ancak `openNotModal` çağrıldığı yerlerde `kupe` parametresinin validation'ı yapılmıyor.
- **Çözüm önerisi:** Fonksiyon içinde kupe değerini sanitize et.

---

### Bulgu #12 — UI Telemetry'de Veri Sızıntısı Potansiyeli
- **Öncelik:** DUSUK
- **Dosya ve Satır:** forms.js:55, 127, 145
- **Sorun:** `uiLog('action', '...', { kupe_no: kupe || devlet, grup: v('a-grup') })` — hassas veri (kupe numarası) telemetry log'larına gidiyor. Log storage backend'i güvenli değilse sızıntı.
- **Çözüm önerisi:** Telemetry'de PII (kişisel kimlik bilgisi) loglanmamalı. Sadece ID hash'lenmeli.

---

## 4. Error Message Exposure

### Bulgu #13 — Stack Trace / Detaylı Hatalar Kullanıcıya Gösteriliyor
- **Öncelik:** YUKSEK
- **Dosya ve Satır:** forms.js:69, 166, 175, 196, 214, 248, 293, 310, 327, 409, 432, 442, 459, 471, 504, 523, 560, 595
- **Sorun:** `toast(e.message, true)` ve `toast('❌ ...: ' + e.message, true)` — Supabase/hata detayları kullanıcıya gösteriliyor. Bu bilgiler saldırgana backend yapısını açıklar.
- **Çözüm önerisi:**
```javascript
catch (e) {
  // Üretimde detaylı mesajı logla, kullanıcıya genel mesaj göster
  console.error('submitAnimal error:', e);
  toast('⚠️ İşlem sırasında bir hata oluştu. Lütfen tekrar deneyin.', true);
}
```

---

### Bulgu #14 — RPC Başarısız Hatalarda Yanıt Objesi Direkt Kullanımı
- **Öncelik:** ORTA
- **Dosya ve Satır:** forms.js:174, 196, 248, 310, 327, 459, 471
- **Sorun:** `res?.ok === false` kontrolü yapılıyor ama `res.mesaj` veya `result.error` direkt kullanıcıya gösteriliyor. Bu mesajlar DB schema hakkında bilgi sızdırabilir.
- **Çözüm önerisi:** `result.mesaj` yerine sabit hata mesajları kullan veya mesaj içeriğini kontrol et.

---

## 5. Authentication Issues

### Bulgu #15 — Online Kontrolü Var Ama Auth Token Yenileme Yok
- **Öncelik:** ORTA
- **Dosya ve Satır:** forms.js:34, 116, 141, 193, 208, 267, 294, 347, 407, 440, 455, 486, 517, 548, 573
- **Sorun:** Her fonksiyon başında `navigator.onLine` kontrolü var ama Supabase session expiry kontrolü yok. Token süresi dolmuşsa kullanıcı hata mesajı görür.
- **Çözüm önerisi:**
```javascript
async function checkAuth() {
  const { data: { session }, error } = await db.auth.getSession();
  if (error || !session) {
    toast('⚠️ Oturum süresi dolmuş. Lütfen tekrar giriş yapın.', true);
    return false;
  }
  return true;
}
```

---

## Genel Öneriler

1. **XSS Koruması:** Tüm `innerHTML` kullanımları DOMPurify ile sanitize edilmeli veya `textContent`/`createElement` kullanılmalı.

2. **Input Validation:** Tüm kullanıcı girdileri client-side validation'dan geçirilmeli (bu sadece UX, backend de mutlaka validate etmeli).

3. **Error Handling:** Hata mesajları kullanıcıya gösterilmeden önce sanitize edilmeli. Supabase/DB detayları log'lanmalı, kullanıcıya generic mesaj gösterilmeli.

4. **RPC Kullanımı:** Mevcut kod RPC kullanıyor — bu doğru. Ancak tüm PATCH/INSERT işlemlerinin RPC'ye taşınması önerilir (forms.js:459, 471, 477, 485, 489, 580 `write()` kullanıyor).

5. **Session Management:** Auth token expiry kontrolü eklennmeli.

---

**Analiz Sonu:** 15 güvenlik bulgusu tespit edildi. 2 KRITIK öncelikli bulgu (XSS) acilen düzeltilmelidir.
