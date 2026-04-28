# Güvenlik Analiz Raporu — api.js

**Analiz Tarihi:** 2026-04-17  
**Worker:** WORKER_SECURITY_1  
**Dosya:** `/root/egesut-erp1/js/api.js`  
**Analiz Kapsamı:** API Key exposure, XSS, SQL injection, CSRF, Rate limiting, Input validation

---

## 1. API Key Exposure

| Alan | Değer |
|---|---|
| **Öncelik** | KRITIK |
| **Dosya ve Satır** | api.js:9–10 |
| **Sorun** | Supabase anon key **açık metin** olarak kod içinde hardcoded. Bu anahtar tarayıcıda çalışan JavaScript'e gömülü ve bu nedenle herhangi bir kullanıcı tarafından görülebilir. İstemci tarafı kodunun Git'e commit edilmesi, anahtarın sızmasına yol açar. |

> **Not:** Supabase anon key'lerin istemci tarafında görünür olması **beklenen bir davranıştır** (RLS ile korunması gerekir). Ancak commit geçmişine girdiğinde anahtar değiştirme gerektirir ve analiz araçları tarafından tespit edilebilir.

| **Öncelik** | KRITIK |
|---|---|
| **Dosya ve Satır** | api.js:9–10 |
| **Sorun** | Supabase anon key **açık metin** olarak kod içinde hardcoded. Bu anahtar tarayıcıda çalışan JavaScript'e gömülü ve bu nedenle herhangi bir kullanıcı tarafından görülebilir. İstemci tarafı kodunun Git'e commit edilmesi, anahtarın sızmasına yol açar. |
| **Çözüm önerisi** | 1. Anon key'i `.env` dosyasına taşı → Vite/Webpack build-time interpolation kullan. 2. `supabase-key-exposure` ve benzeri secret tarama araçlarını CI pipeline'a ekle. 3. Mevcut anahtarı Supabase dashboard üzerinden **rotate** et. 4. Anahtarı `window.SB_KEY` gibi ortam değişkeni yerine, build-time constant olarak enjekte et. |

---

## 2. XSS Vulnerabilities

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:13 (rpc fonksiyonu hata mesajı拼接) |
| **Sorun** | `rpc()` fonksiyonunda hata mesajı doğrudan concatenation ile oluşturuluyor (`"[" + name + "] " + error.message`). `error.message` Supabase'ten gelen veriden geldiği için bu değer doğrudan kullanıcı arayüzüne yansıtılırsa XSS riski doğar. Şu an `toast()` üzerinden gösteriliyor; `toast()`'in innerHTML kullanıp kullanmadığı kontrol edilmeli. |
| **Çözüm önerisi** | `error.message` değerini `textContent` üzerinden veya DOMPurify ile sanitize ederek kullan. `toast()` fonksiyonunun `textContent` kullandığından emin ol. |

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:14 |
| **Sorun** | `rpcOptimistic()` içinde hata mesajı `toast('❌ ' + e.message)` ile gösteriliyor. Aynı XSS riski burada da geçerli — kullanıcıdan gelen veya Supabase'in döndüğü kötü niyetli veri doğrudan DOM'a enjekte edilebilir. |
| **Çözüm önerisi** | `toast()` fonksiyonunun `innerHTML` mi yoksa `textContent` mi kullandığını `ui.js` içinde doğrula. Mevcut ise, `innerHTML` kullanımını `textContent` ile değiştir. |

| **Öncelik** | DUSUK |
|---|---|
| **Dosya ve Satır** | api.js:248 |
| **Sorun** | `console.log('[ui_log]', payload.new)` — Supabase Realtime'dan gelen `payload.new` verisi doğrudan `console.log`'a yazılıyor. Bu doğrudan bir XSS riski oluşturmaz, ancak verinin içeriği güvenilmeyen bir kaynaktan geliyor. |
| **Çözüm önerisi** | Debug amaçlı bu satır kabul edilebilir. Ancak production'da `console.log` yerine structured logging (JSON) kullanmayı düşün. |

---

## 3. SQL Injection Risk

| **Öncelik** | DUSUK |
|---|---|
| **Dosya ve Satır** | api.js:107–108 |
| **Sorun** | `_writePatch()` fonksiyonunda `filter.match(/id=eq\.([^&]+)/)` regex ile id çıkarılıyor. Regex (`[^&]+`) injection'a karşı kısmen koruma sağlar — ampersand karakteri `#` ve sorgu manipülasyonu engellenir. Ancak bu regex tabanlı filtrasyon yeterince güçlü değil. |
| **Çözüm önerisi** | Filtre parametresi yalnızca güvenilir kod (kendı içinde `app.js`/`forms.js`) tarafından oluşturulduğundan emin ol. Harici girdi bu fonksiyona erişememeli. Belgeleme ekle ve fallback validation ekle. |

| **Öncelik** | DUSUK |
|---|---|
| **Dosya ve Satır** | api.js:192 |
| **Sorun** | `syncNow()` içinde `idMatch = (op.filter || '').match(/id=eq\.([^&]+)/)` — queued operation'lardan gelen filter değeri işleniyor. Queue verisi yerel IndexedDB'de saklanır, bu nedenle doğrudan SQL injection riski düşük. Ancak queued operation'lar kötü niyetli bir katman tarafından oluşturulabilir. |
| **Çözüm önerisi** | Queue'ya yazılmadan önce `filter` formatını valide eden bir yardımcı fonksiyon ekle. Sadece `id=eq.` formatına izin ver. |

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:232–246 |
| **Sorun** | `initRealtime()` içinde hardcoded tablo isimleri var (`hayvanlar`, `gorev_log`, vb.). Bu değerler doğrudan Supabase'e gönderiliyor. Eğer tablo isimleri dışarıdan (URL parametresi, form girdisi vb.) alınırsa SQL injection riski oluşur. |
| **Çözüm önerisi** | `REALTIME_TABLES` sabit listesinde olmayan tablo isimlerini reddeden whitelist validation ekle. Mevcut kullanımda tablo isimleri hardcoded olduğundan risk düşük. |

---

## 4. CSRF Protection

| **Öncelik** | YUKSEK |
|---|---|
| **Dosya ve Satır** | api.js:9–10, 13 |
| **Sorun** | Supabase SDK, isteklerde otomatik olarak `apikey` header'ını kullanıyor ancak **CSRF token mekanizması yok**. Supabase anon key kullandığında, tarayıcı cross-origin isteklerinde cookie göndermez — bu nedenle geleneksel CSRF riski klasik REST API'ye göre daha düşüktür. Ancak **Realtime subscription'ları** CSRF koruması olmadan açık. |
| **Çözüm önerisi** | 1. Supabase'de `RLS (Row Level Security)` politikalarının tüm tablolarda etkin olduğundan emin ol. 2. Realtime channel'ları için subscription'ı sadece authenticated isteklerle kullanılabilir kıl. 3. Hassas işlemler için ek authorization katmanı ekle (sunucu tarafında RPC permission fonksiyonları). |

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:232 |
| **Sorun** | `initRealtime()` — Realtime WebSocket bağlantısı herhangi bir ek yetkilendirme olmadan kuruluyor. Eğer kullanıcı session'ı varsa Supabase token'ı otomatik gönderiyor, ancak açık bir yetkilendirme kontrolü yok. |
| **Çözüm önerisi** | Realtime subscription'ı kurulmadan önce kullanıcı session'ının geçerli olduğunu `db.auth.getSession()` ile kontrol et. |

---

## 5. Rate Limiting

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:12–13, 209–220 |
| **Sorun** | `rpc()` ve `syncNow()` fonksiyonlarında **istemci tarafı rate limiting yok**. Kullanıcı kötü niyetli bir kod enjekte ederse (XSS) veya bir betik çalıştırırsa, sürekli RPC isteği gönderilebilir. `pullTables` ve `rpcOptimistic` çağrıları debounce edilmiş olsa da, `syncNow()` ve `dbUpdate/dbInsert` için rate limit yok. |
| **Çözüm önerisi** | 1. İstemci tarafında basit bir rate limiter implementasyonu ekle: `lastCallTime` track edilerek 1 saniye içinde aynı RPC'ye izin verme. 2. Supabase'de `pgRouting` veya API Gateway seviyesinde sunucu tarafı rate limiting aktif et. 3. `syncNow()` döngüsüne anti-spam koruması ekle. |

| **Öncelik** | DUSUK |
|---|---|
| **Dosya ve Satır** | api.js:261–269 |
| **Sorun** | `startBackgroundSync(intervalMs = 30000)` — Her 30 saniyede bir arka plan sync çalışıyor. Bu, kullanıcı etkileşimi olmadan arka planda sürekli istek gönderir. Legitimate kullanımda sorun değil, ancak çok sayıda kullanıcı aynı anda bağlanırsa sunucu yükü oluşabilir. |
| **Çözüm önerisi** | Background sync interval'ını yapılandırılabilir yap ve Supabase rate limit planına göre ayarla. Realtime aktifken polling'i devre dışı bırakıldığından emin ol (zaten `stopBackgroundSync()` çağrılıyor — doğru). |

---

## 6. Input Validation

| **Öncelik** | YUKSEK |
|---|---|
| **Dosya ve Satır** | api.js:42–44 |
| **Sorun** | `idbPut()` fonksiyonu, IndexedDB'ye yazmadan önce **hiçbir validation yapmıyor**. `rows` parametresi bir nesne dizisi olmalı, ancak boş dizi, null, yanlış tip veya eksik `id` alanı olan veri kabul ediliyor. Bu, bozuk verinin local storage'a yazılmasına yol açar. |
| **Çözüm önerisi** | `idbPut()` içinde `rows` için tip kontrolü ekle: `if (!Array.isArray(rows)) throw new Error('Invalid rows type')`. `id` alanı için validation ekle. |

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:78–80 |
| **Sorun** | `dbInsert()` — Gelen `rows` verisinden `null`, `undefined`, `''` değerleri filtreleniyor ancak **veri tipi kontrolü yok**. Yanlış tipteki veri (örn. `id` yerine sayı yerine string beklenirken integer gelmesi) kabul ediliyor. |
| **Çözüm önerisi** | Temel schema validation ekle: `id` alanının UUID/string olduğunu kontrol eden bir yardımcı fonksiyon kullan. |

| **Öncelik** | ORTA |
|---|---|
| **Dosya ve Satır** | api.js:100–108 |
| **Sorun** | `_writePatch()` — `arr` parametresi için validation yok. `arr[0]` doğrudan merge işlemine giriyor. Boş dizi gelirse `arr[0]` `undefined` olur ve beklenmedik davranış oluşur. |
| **Çözüm** | `if (!arr || !Array.isArray(arr) || !arr.length) return null;` kontrolü ekle. |

| **Öncelik** | DUSUK |
|---|---|
| **Dosya ve Satır** | api.js:209 |
| **Sorun** | `syncNow()` içinde queued operation'ların yapısı doğrulanmıyor. `op.table`, `op.method`, `op.data` alanları eksik olsa bile kod çalışmaya devam eder. |
| **Çözüm önerisi** | Her queued operation için yapısal validation ekle: `if (!op.table || !op.data) { await removeFromQueue(op._qid); continue; }` |

| **Öncelik** | DUSUK |
|---|---|
| **Dosya ve Satır** | api.js:277 |
| **Sorun** | `getData()` fonksiyonunda `filterFn` parametresi için validation yok. Yanlış tipte bir fonksiyon geçilirse hata oluşabilir. |
| **Çözüm önerisi** | `if (filterFn && typeof filterFn !== 'function') throw new Error('filterFn must be a function')` |

---

## Özet Bulgu Sayıları

| Kategori | KRITIK | YUKSEK | ORTA | DUSUK | Toplam |
|---|---|---|---|---|---|
| API Key Exposure | 1 | — | — | — | 1 |
| XSS Vulnerabilities | — | — | 2 | 1 | 3 |
| SQL Injection Risk | — | — | 1 | 2 | 3 |
| CSRF Protection | — | 1 | 1 | — | 2 |
| Rate Limiting | — | — | 1 | 1 | 2 |
| Input Validation | — | 1 | 3 | 2 | 6 |
| **Toplam** | **1** | **2** | **8** | **6** | **17** |

## Kritik Öncelikli Aksiyonlar

1. **[KRITIK]** Supabase anon key'i build-time environment variable'a taşı ve mevcut anahtarı rotate et.
2. **[YUKSEK]** Supabase RLS politikalarının tüm tablolarda etkin olduğunu doğrula.
3. **[YUKSEK]** `toast()` fonksiyonunun `textContent` kullandığını `ui.js`'te kontrol et.

---

*Worker: WORKER_SECURITY_1 | Analiz dosyası oluşturuldu: 2026-04-17T12:42:00Z*
