# Task-dev-001: Test Hataları — IDB Store, Duplicate Telemetry, Tohumlama 42883

**Durum:** bekliyor
**Branch:** gwen/dev
**Tarih:** 2026-04-02
**Öncelik:** kritik

---

## Test Sonucu

Site test edildi, 3 aktif hata tespit edildi.

---

## Hata 1 — IDBDatabase: object store not found (KRİTİK)

**Hata:** `Failed to execute 'transaction' on 'IDBDatabase': One of the specified object stores was not found`

**Neden:** `js/api.js:10`'daki `TABLES` dizisinde `vaccines` eksik. `ui.js:485`'te `idbGetAll('vaccines')` çağrılıyor ama store hiç oluşturulmamış.

**Mevcut TABLES (`api.js:10`):**
```js
const TABLES = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log','cop_kutusu',
                'cases','diseases','drugs','drug_classes','drug_products','drug_administrations'];
```

**Eksik:** `vaccines` — DB'de var, IDB'de yok.

**Fix:**
1. `TABLES` dizisine `'vaccines'` ekle
2. `DB_VER` değerini 1 artır (şu an `13` → `14` yap) — mevcut IDB'yi upgrade etmesi için

**Kontrol:** Ayrıca şu tablolar DB'de var ama TABLES'da yok — bunlara `idbGetAll` çağrısı var mı kontrol et:
- `hastalik_log`, `tedavi`, `treatment_days`, `vaccination_log`, `vaccination_schedule`

Eksik olanları da ekle, DB_VER'i tek seferinde bump et.

---

## Hata 2 — `_origConsoleError` duplicate (KRİTİK)

**Hata:** `Uncaught SyntaxError: Identifier '_origConsoleError' has already been declared` — `app.js:1105`

**Neden:** Telemetry/console.error override kodu `app.js`'e iki kez eklenmiş.

**Fix:**
1. `grep -n "_origConsoleError" js/app.js` → iki tanımı bul
2. Birini sil, diğerini koru
3. Hangisinin daha güncel/doğru olduğuna bak (window.onerror + console.error override içermeli)

---

## Hata 3 — Tohumlama sonucu 42883 (PostgreSQL: undefined_function)

**Hata:** PostgreSQL error 42883 — tohumlama sonucu kaydederken

**Neden:** DB'de `tohumlama_sonuc_bos` iki kez tanımlı, farklı imzalarla:
- `tohumlama_sonuc_bos(p_tohumlama_id text)`
- `tohumlama_sonuc_bos(p_tohumlama_id text, p_notlar text)`

Frontend hangisini çağırıyor kontrol et. `rpcOptimistic('tohumlama_sonuc_bos', {...})` çağrısını bul, parametrelere bak.

**Fix:**
- `js/forms.js`'te `tohumlama_sonuc_bos` çağrısını bul
- Gönderilen parametreler DB imzasıyla eşleşiyor mu kontrol et
- Eşleşmiyorsa frontend parametrelerini düzelt

---

## Kabul Kriterleri

- [ ] Hata 1: `vaccines` TABLES'a eklendi, DB_VER bump edildi, diğer eksik tablolar kontrol edildi
- [ ] Hata 2: `_origConsoleError` duplicate kaldırıldı, tek tanım kaldı
- [ ] Hata 3: tohumlama sonucu 42883 hatası giderildi
- [ ] `node --check js/app.js js/api.js js/forms.js` geçti
- [ ] Push edildi, `task-dev-001-done.md` yazıldı

---

## Notlar

- IndexedDB upgrade için kullanıcının tarayıcıyı kapatıp açması gerekebilir (hard refresh)
- `_origConsoleError` fix'ten sonra loglar temizlenecek
- Tohumlama fix sonrası yeniden test et: Gebe/Boş seç → DB'ye yazılıyor mu?
