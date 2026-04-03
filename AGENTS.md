# EgeSüt ERP — Agent Talimatları

Bu dosya AI agent'ları için proje kurallarını tanımlar. Her yeni oturumda oku.

## Stack

- Vanilla JS PWA, tek `index.html`, framework yok, build step yok
- Supabase backend (PostgreSQL + RPC)
- IndexedDB offline cache
- Deploy: GitHub Pages (her push otomatik)

## Dosya Haritası

```
js/api.js     — Supabase client, IndexedDB, RPC wrapper (~400 satır)
js/app.js     — Init, routing, global state, helpers (~780 satır)
js/ui.js      — Tüm render fonksiyonları (~3000 satır)
js/forms.js   — Form submit, RPC çağrıları (~960 satır)
js/config.js  — Sabitler, GRUP_PADOK mapping
js/state.js   — getState / setState (AppState class)
index.html    — HTML + CSS + tüm modaller
```

---

## Komutlar

### Syntax Kontrolü (Zorunlu)
```bash
node --check js/api.js js/forms.js js/app.js js/ui.js js/state.js js/config.js
```

### Test
```bash
# Tüm testler
npm test

# Tek test dosyası
npx playwright test tests/smoke.spec.js

# Headed mode (görsel)
npm run test:headed

# Rapor
npm run test:report
```

### Duplicate Kontrol
```bash
grep -n "functionName" js/*.js
```

### DB Migration
```bash
npx supabase db push
```

---

## Kritik Kurallar (İhlal Etme)

### 1. Sadece RPC ile Yaz
```javascript
// ✅ DOĞRU
await rpc('hayvan_ekle', { p_kupe_no: '...', ... });

// ❌ YASAK — direkt REST
await db.from('hayvanlar').insert({ ... });
await db.from('hayvanlar').update({ ... });
```
Tüm yazmalar `.claude/rpc-reference.md`'deki RPC'lerden biri olmalı.

### 2. Okuma IndexedDB'den
```javascript
// ✅ DOĞRU
const animals = await idbGetAll('hayvanlar');

// ❌ YASAK — direkt Supabase okuma (sadece sync sırasında)
const animals = await db.from('hayvanlar').select('*');
```

### 3. Fonksiyon Duplikat Kontrolü
```bash
grep -n "fonksiyonAdi" js/*.js
```
Aynı fonksiyon 2 dosyada varsa bug oluşur — önce temizle.

### 4. Paralel Yazma Yasak
Birden fazla dosyayı aynı anda düzenleme. Bir dosyayı bitir, sonra diğerine geç.

---

## Kod Stili

### Genel
- **Türkçe değişken/fonksiyon isimleri** — projenin dili Türkçe
- **ES6+** — arrow functions, async/await, template literals
- **Tek tırnak** — stringler için
- **Noktalı virgül** — zorunlu
- **2 boşluk indent** — spaces, tabs yok

### Fonksiyonlar
```javascript
// ✅ async fonksiyonlar tercih et
async function loadAnimals() { ... }

// ✅ erken return kullan
async function submitAnimal(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet gerekli', true); return; }
  // ...
}

// ❌ callback yerine async/await
getData('hayvanlar').then(data => { ... }); // Kullanma
const data = await getData('hayvanlar'); // Kullan
```

### Değişkenler
```javascript
// ✅ const/let, var yok
const API_URL = 'https://...'; // sabitler UPPER_SNAKE
let count = 0; // değişkenler camelCase

// ✅ açıklayıcı isimler
const hayvanlar = await idbGetAll('hayvanlar');
const gebeTohumlamalar = tohumlama.filter(t => t.sonuc === 'Gebe');

// ❌ tek harf veya kısaltmalar (karakter sayısı < 3)
const a = getData('x'); // Kullanma
```

### DOM Erişimi
```javascript
// ✅ g() helper kullan
function g(id) { return document.getElementById(id); }
const el = g('element-id');

// ✅ null kontrolü zorunlu
const el = g('element-id');
if (el) el.value = '';

// ✅ optional chaining
toast(data?.gorev_sayisi ?? 0 + ' görev');
```

### Hata Yönetimi
```javascript
// ✅ try-catch with toast
try {
  await rpc('hayvan_ekle', params);
  toast('✅ Başarılı');
} catch (e) {
  toast('❌ ' + e.message, true);
}

// ✅ finally ile buton reset
finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; } }
```

### Template Literals
```javascript
// ✅
const html = `<div class="animal-card" onclick="openDet('${a.id}')">
  ${a.kupe_no || '—'}
</div>`;

// ❌ string concatenation
var html = '<div>' + a.kupe_no + '</div>';
```

---

## IndexedDB

### TABLES dizisi (api.js)
```javascript
const TABLES = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log',
                'cop_kutusu','cases','diseases','drugs','drug_classes','drug_products',
                'drug_administrations','vaccines','vaccination_log'];
```

### Yeni tablo eklerken
1. TABLES dizisine ekle
2. DB_VER'i 1 artır
3. `node --check` çalıştır

---

## Domain Kuralları

- **Tohumlama:** `bekliyor → gebe → doğum` veya `boş/abort`. State machine'i bypass etme.
- **Stok ledger:** `stok_hareket` asla silinmez, düzeltme yeni kayıt olarak girilir.
- **Hayvan küpe:** Benzersiz, format `TR-XXXX`.
- **Gebelik:** 280 gün ± 10. Hesaplama DB'de yapılır.

---

## Commit Formatı

```
fix: kısa açıklama
feat: kısa açıklama  
chore: kısa açıklama
```

---

## Branch Kuralı

- `main` — production, dokunma
- `fix/tech-debt` — aktif teknik borç
- Kendi branch: `git checkout -b fix/aciklama`

---

## IndexedDB Helper Fonksiyonları

```javascript
idbGetAll('tablo')           // Tüm kayıtları al
idbPut('tablo', [rows])      // Kayıt ekle/güncelle
idbDelete('tablo', id)       // Kayıt sil
idbClearAndPut('tablo', rows) // Temizle ve yeniden yaz
```

---

## State Yönetimi

İki mekanizma var — tutarlı kullan:

1. **AppState (state.js):**
```javascript
getState('animals');  // oku
setState('animals', _A); // yaz
```

2. **Global değişkenler:**
```javascript
let _A = [], _S = []; // animals, stock
```

**Öneri:** Tutarlılık için AppState kullan veya global değişkenlere devam et — karışık kullanma.