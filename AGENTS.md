# EgeSüt ERP — Agent Talimatları

Bu dosya OpenCode, Codex CLI ve diğer AI agent'lar için proje kurallarını tanımlar.

## Stack

- Vanilla JS PWA, tek `index.html`, framework yok, build step yok
- Supabase backend (PostgreSQL + RPC)
- IndexedDB offline cache
- Deploy: GitHub Pages (her push otomatik)

## Dosya Haritası

```
js/api.js     — Supabase client, IndexedDB, RPC wrapper (~395 satır)
js/app.js     — Init, routing, global state (~780 satır)
js/ui.js      — Tüm render fonksiyonları (~3000 satır)
js/forms.js   — Form submit, RPC çağrıları (~960 satır)
js/config.js  — Sabitler, GRUP_PADOK mapping
js/state.js   — getState / setState
```

## Kritik Kurallar — İhlal Etme

### 1. Sadece RPC ile Yaz
```javascript
// ✅ DOĞRU
await rpc('hayvan_ekle', { p_kupe: '...', ... });

// ❌ YASAK — direkt REST
await db.from('hayvanlar').insert({ ... });
await db.from('hayvanlar').update({ ... });
```

Tüm yazma işlemleri `.claude/rpc-reference.md` dosyasındaki RPC'lerden biri olmalı.

### 2. Okuma IndexedDB'den
```javascript
// ✅ DOĞRU
const animals = await idbGetAll('hayvanlar');

// Supabase'den direkt okuma sadece sync sırasında
```

### 3. Fonksiyon Yazmadan Önce Duplikat Kontrol
```bash
grep -n "fonksiyonAdi" js/*.js
```
Aynı fonksiyon 2 dosyada varsa bug yaratır — önce temizle.

### 4. Paralel Yazma Yasak
Birden fazla dosyayı aynı anda düzenleme. Bir dosyayı bitir, sonra diğerine geç.

### 5. node --check Zorunlu
Her değişiklik sonrası:
```bash
node --check js/api.js js/forms.js js/app.js js/ui.js
```

## Domain Kuralları (Özet)

- **Tohumlama state machine:** `bekliyor → gebe → doğum` veya `boş/abort`. Bypass etme.
- **Stok ledger immutable:** `stok_hareket` asla silinmez, düzeltme yeni kayıt olarak girilir.
- **Hayvan küpe:** Benzersiz, format `TR-XXXX`. Free-text değil.
- **Gebelik süresi:** 280 gün ± 10. Hesaplama DB'de yapılır, frontend'de değil.

Detay: `.claude/domain-rules.md`

## RPC Listesi (Özet)

```
hayvan_ekle, hayvan_guncelle, hayvan_not_ekle
tohumlama_kaydet, dogum_kaydet, abort_kaydet, kizginlik_kaydet
tohumlama_sonuc_bos, tohumlama_sonuc_gebe
hastalik_kaydet, hastalik_guncelle, hastalik_kapat, hastalik_sil
tedavi_ekle, tedavi_sil, tedavi_guncelle, update_treatment_time
create_case, add_treatment_day, add_drug_administration, close_case
stok_ekle, stok_guncelle
geri_al, irk_listesi, hekim_ekle
```

Tam imzalar: `.claude/rpc-reference.md`

## IndexedDB Tabloları

```javascript
const TABLES = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                 'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log','cop_kutusu',
                 'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                 'vaccines','vaccination_log'];
```

`idbGetAll()` ile sadece bu tablolar okunabilir. Yeni tablo eklenirse hem TABLES dizisine ekle hem DB_VER'i 1 artır.

## Commit Formatı

```
fix: kısa açıklama
feat: kısa açıklama
chore: kısa açıklama
```

## Test

```bash
# Syntax kontrolü — her commit öncesi zorunlu
node --check js/api.js js/forms.js js/app.js js/ui.js

# Duplikat fonksiyon kontrolü
grep -n "functionName" js/*.js
```

## Branch Kuralı

- `main` — production, dokunma
- `fix/tech-debt` — aktif teknik borç branch'i
- Kendi branch'ini aç: `git checkout -b fix/aciklama`
