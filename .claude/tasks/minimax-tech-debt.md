# MiniMax M2.5 — Teknik Borç Kapatma Görevi

**Tarih:** 2026-04-03
**Model:** minimax/minimax-m2.5 (OpenRouter)
**Branch:** fix/tech-debt (main'den aç)
**Öncelik:** Sırayla uygula — sonraki göreve geçmeden öncekini bitir
**Push:** Her görev bitiminde commit + push

---

## Proje Özeti

Vanilla JS PWA, Supabase backend, offline-first. Build step yok.
Tüm yazma işlemleri Supabase RPC üzerinden geçer — direkt REST INSERT/UPDATE yasak.

```
js/api.js     — Supabase client, IndexedDB sync, RPC wrapper
js/app.js     — Init, routing, global state
js/ui.js      — Tüm render fonksiyonları (3000 satır)
js/forms.js   — Form submit, RPC çağrıları
js/config.js  — Sabitler
js/state.js   — getState/setState
```

---

## GÖREV 1 — vaccines IDB Store Eksikliği (KRİTİK)

**Hata:** `Failed to execute 'transaction' on 'IDBDatabase': One of the specified object stores was not found`

**Konum:** `js/api.js:10` — TABLES dizisi

**Sorun:** `vaccines` ve `vaccination_log` tabloları `ui.js`'te `idbGetAll()` ile çağrılıyor ama `TABLES` dizisinde yok, dolayısıyla IDB store hiç oluşturulmamış.

**Fix:**
1. `js/api.js`'te `TABLES` dizisine `'vaccines'` ve `'vaccination_log'` ekle
2. `DB_VER` sayısını 1 artır (örn. 13 → 14) — IDB upgrade tetiklensin
3. `grep -n "idbGetAll\|idbPut" js/ui.js js/forms.js` ile başka eksik tablo var mı kontrol et
4. `node --check js/api.js` geçmeli

**Kabul kriteri:** IDB transaction hatası yok, vaccines store oluşuyor.

---

## GÖREV 2 — _origConsoleError Duplicate (KRİTİK)

**Hata:** `Uncaught SyntaxError: Identifier '_origConsoleError' has already been declared` — `app.js`

**Fix:**
1. `grep -n "_origConsoleError" js/app.js` — kaç kez tanımlı bul
2. Duplicate tanımı sil, `window.onerror + console.error override` içeren bloğu koru
3. `node --check js/app.js` geçmeli

---

## GÖREV 3 — Tohumlama Sonucu 42883 Hatası (KRİTİK)

**Hata:** PostgreSQL error 42883 (undefined_function) — tohumlama sonucu kaydedilirken

**Sorun:** DB'de `tohumlama_sonuc_bos` iki farklı imzayla tanımlı:
- `tohumlama_sonuc_bos(p_tohumlama_id text)`
- `tohumlama_sonuc_bos(p_tohumlama_id text, p_notlar text)`

Frontend hangi parametrelerle çağırıyor bul, DB imzasıyla eşleştir.

**Fix:**
1. `grep -n "tohumlama_sonuc_bos" js/forms.js js/ui.js` — çağrıyı bul
2. Gönderilen parametrelerle DB imzası eşleşiyor mu kontrol et
3. Frontend parametrelerini doğru imzaya göre düzelt
4. `node --check js/forms.js` geçmeli

---

## GÖREV 4 — Offline Kuyruk REST Bypass (YÜKSEK)

**Konum:** `js/ui.js` — `dataTrafficTekGonder` fonksiyonu

**Sorun:** Offline kuyruktaki işlemler gönderilirken direkt `db.from().insert()` / `db.from().update()` çağrılıyor. Bu RPC kuralını ihlal ediyor, backend validasyonu ve guard'lar atlanıyor.

**Fix:**
1. `grep -n "dataTrafficTekGonder\|_queue\|queueOp" js/ui.js js/api.js` ile kuyruk mekanizmasını anla
2. Kuyruktaki her `op.method` için hangi RPC çağrılması gerektiğini belirle
3. Direkt insert/update yerine ilgili RPC'yi çağır
4. Eğer bazı operasyonlar için uygun RPC yoksa, o operasyonları kuyruğa almayı durdur ve senkron yap

**Not:** Bu görev karmaşık olabilir. Önce kuyruğa ne tür operasyonların girdiğini logla, sonra karar ver.

---

## GÖREV 5 — README Teknik Borç Güncelle

Yukarıdaki görevler tamamlandıkça `README.md`'deki "Aktif Teknik Borç" tablosunu güncelle:
- Çözülen satırları sil
- Hala açık olanları tut
- Yeni bulunan borçları ekle

---

## Çalışma Kuralları

1. **Paralel yazma yasak** — bir dosyayı bitir, sonra diğerine geç
2. **Her görev sonrası:** `node --check js/*.js` çalıştır
3. **Duplicate kontrol:** `grep -n "functionName" js/*.js` — aynı fonksiyon 2 yerde olmasın
4. **Commit formatı:** `fix: [görev no] açıklama`
5. **Branch:** `fix/tech-debt` — main'e dokunma

---

## Tamamlanan Görevler (Bugün Kapatıldı)

Bunları yapma, zaten tamamlandı:
- ✅ api.js: `name` → `table` (dbUpdate/dbInsert hata mesajı)
- ✅ forms.js: `data?.gorev_sayisi` optional chaining
- ✅ forms.js: DOM null kontrolleri (anne-secili-card vb.)
- ✅ forms.js: race condition await düzeltmeleri (abort, gebelik)
