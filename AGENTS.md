# EgeSüt ERP — Agent Talimatları

Bu dosya AI agent'ları için proje kurallarını tanımlar. Her yeni oturumda oku.

---

## ⚠️ MUTLAK YASAKLAR — İhlal Etme

1. **`main` branch'e direkt push YASAK** — sadece Claude merge eder
2. **Paralel dosya yazma YASAK** — bir dosyayı bitir, sonra diğerine geç
3. **Direkt REST write YASAK** — sadece RPC kullan
4. **Task dosyasını güncellemeden commit YASAK** — her görev bitişinde task dosyası güncellenmeli

**Çalışma branch'in:** `.claude/tasks/task-XXX.md` dosyasında belirtilir. Belirtilmemişse `fix/tech-debt` kullan.

```bash
# Her oturumun başında branch'ini kontrol et
git branch
git checkout fix/tech-debt  # değilsen geç

# Push sadece kendi branch'ine
git push origin fix/tech-debt  # ✅
git push origin main           # ❌ YASAK
```

---

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

## Task Dosyası Güncelleme Kuralı (ZORUNLU)

Her görev tamamlandığında, commit atmadan önce task dosyasını güncelle:

### 1. Task dosyasındaki durumu güncelle
```
**Durum:** bekliyor  →  **Durum:** tamamlandı
```

### 2. Done raporu yaz
`task-XXX-done.md` dosyası oluştur, şunları içermeli:
```markdown
# Task-XXX Done

**Tarih:** YYYY-MM-DD
**Süre:** ~X saat

## Yapılanlar
- [ ] Adım 1 — ne yapıldı
- [ ] Adım 2 — ne yapıldı

## Doğrulama
Kabul kriterlerini buraya kopyala, her birinin sonucunu yaz.

## Commit(ler)
- abc1234 — commit mesajı
```

### 3. Commit sırası
```bash
# Önce task dosyasını güncelle
git add .claude/tasks/task-XXX.md .claude/tasks/task-XXX-done.md
git commit -m "chore: task-XXX tamamlandı"

# Sonra kod commitlerini at
git add ...
git commit -m "fix/feat: ..."

git push origin fix/tech-debt
```

**Bu kural Claude dahil tüm agentler için geçerlidir.**

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
---

## Backend & DevOps

### Kimlik Bilgileri

Tokenlar `.claude/CREDENTIALS.md` dosyasında (gitignore'lu, lokal). **Her oturumun başında oku.**

```bash
cat .claude/CREDENTIALS.md
```

---

### Supabase

**Project ref:** `zqnexqbdfvbhlxzelzju`
**URL:** `https://zqnexqbdfvbhlxzelzju.supabase.co`

#### Migration Yazma Kuralları

```
supabase/migrations/YYYYMMDDHHMMSS_aciklama.sql
```

Her migration:
```sql
-- Migration: ne yapıyor
-- Etkiler: hangi tablo/fonksiyon değişiyor
-- Geri alınabilir: nasıl geri alınır

-- İdempotent yaz:
CREATE OR REPLACE FUNCTION ...
DROP FUNCTION IF EXISTS ...
ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...
```

#### Migration Deploy — 3 Yöntem

**Yöntem 1 — GitHub Actions (tercih edilen):**
```bash
git add supabase/migrations/yeni_migration.sql
git commit -m "migration: açıklama"
git push origin main  # Actions otomatik tetiklenir → Supabase'e push
```

**Yöntem 2 — Supabase CLI:**
```bash
export SUPABASE_ACCESS_TOKEN=sbp_xxx  # .claude/CREDENTIALS.md'den al
npx supabase db push --project-ref zqnexqbdfvbhlxzelzju
```

**Yöntem 3 — SQL Editor (token yoksa):**
SQL'i kopyala → https://supabase.com/dashboard/project/zqnexqbdfvbhlxzelzju/sql/new → çalıştır
Sonra migration dosyasını repoya ekle (izleme için).

#### Migration Doğrulama

```bash
# Fonksiyon var mı kontrol et
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/fonksiyon_adi" \
  -X POST \
  -H "apikey: ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_param": "test"}' | head -c 200

# Tablo kolonları
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/tablo_adi?limit=1" \
  -H "apikey: ANON_KEY" | head -c 300
```

ANON_KEY değeri: `.claude/CREDENTIALS.md`'de.

#### GitHub Actions Hata Aldığında

```bash
# Actions loglarını görüntüle (gh CLI tablet'te çalışmayabilir)
# Alternatif: https://github.com/Meliksahtokur/egesut-erp1/actions

# Actions sırrı eksikse → repo sahibine bildir:
# Settings → Secrets → Actions → SUPABASE_ACCESS_TOKEN ekle
```

---

### GitHub

**Repo:** `Meliksahtokur/egesut-erp1`
**Auth:** `~/.netrc` — push otomatik çalışır, ekstra token gerekmez

#### Push & Branch

```bash
# Normal push
git push origin fix/tech-debt

# Main'e push (sadece Claude yapabilir)
git push origin master:main

# PR açmak (gh CLI çalışmıyorsa browser'dan)
# https://github.com/Meliksahtokur/egesut-erp1/compare
```

#### Actions Başarısız Olursa

1. `.github/workflows/` klasörünü oku — hangi step hata verdi
2. Migration syntax hatası mı? → SQL'i kontrol et
3. Secret eksik mi? → Claude'a bildir, Claude repo sahibine iletir
4. Hata düzelmiyorsa → Claude'a `task-XXX-done.md` ile rapor ver

---

### Telemetri ile Test

Frontend hataları otomatik `ui_logs` tablosuna yazılır (`js/app.js` → `uiLog()`).

#### Log Okuma

```bash
# Son 20 hata
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/ui_logs?select=level,message,source,created_at&order=created_at.desc&limit=20" \
  -H "apikey: ANON_KEY" \
  -H "Authorization: Bearer ANON_KEY"
```

#### Log Seviyeleri

| Seviye | Ne zaman | Örnek |
|---|---|---|
| `error` | JS hatası, uncaught exception | SyntaxError, null reference |
| `action` | Kullanıcı aksiyonu | tohumlama_submit, dogum_kaydet |
| `warn` | Uyarı | offline mod, fallback |

#### Test Protokolü

1. Değişikliği deploy et (push → GitHub Pages ~1 dk)
2. Canlıda işlemi yap
3. Log oku → hata var mı kontrol et
4. Temizse tamamlandı, değilse düzelt

---

### RPC Test Etme

```bash
# RPC'yi direkt test et
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/RPC_ADI" \
  -X POST \
  -H "apikey: ANON_KEY" \
  -H "Authorization: Bearer ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_param1": "deger1"}'

# Beklenen: {"ok": true, ...} veya {"ok": false, "error": "..."}
# Hata: {"code": "42883"} → fonksiyon bulunamadı (imza hatası)
# Hata: {"code": "42501"} → permission hatası (RLS)
```

---

### Sık Karşılaşılan Backend Hataları

| Hata kodu | Anlam | Çözüm |
|---|---|---|
| `42883` | Fonksiyon bulunamadı | İmza uyuşmuyor, param sayısı/tipi kontrol et |
| `42501` | Permission denied | RLS policy eksik, `SECURITY DEFINER` ekle |
| `23505` | Unique constraint | Duplicate kayıt, önce kontrol et |
| `23503` | Foreign key violation | İlgili kayıt yok, önce parent ekle |
| `PGRST116` | Row not found | `.single()` yerine `.maybeSingle()` kullan |

