# Plan Review — ReFactorRoadmap Implementation Plans

**Reviewed:** 2026-05-13
**Git range:** `23ccdb0..6646df2`
**Files:** 6 plan documents in `docs/superpowers/plans/`

---

## Plan-by-Plan Review

### Plan 1: Aşama 1 Altyapı Tamamlama
`2026-05-13-asama1-altyapi-tamamlama.md`

**Strengths:**
- İyi sıralanmış: helpers.js → modal.js → autocomplete → state migration (bağımlılık zinciri doğru)
- "Neye dokunma" bölümü net: config.js, migration'lar korunuyor
- Task 4 (state migration) için insan onayı uyarısı var
- Syntax check ve grep doğrulama komutları pratik

**Issues:**

**Important:**
1. **task 1 ve 2'deki `index.html` edit'lerinde sıra hatası olabilir**
   - Task 1'de `<script src="js/utils/helpers.js">` ekleniyor, task 2'de `<script src="js/utils/modal.js">` ekleniyor
   - Her iki task da commit ediliyor. İlk commit sonrası `modal.js` eksik kalır, `openM` undefined olur.
   - **Fix:** Ya tek commit yap, ya da task 1'de her ikisini birden html'e ekle.

2. **Task 5'te `getState('stock')` mutable array döndürüyor**
   - `getState` direkt referans döndürüyor. `const stock = getState('stock'); stock.push(x)` → state değişiyor ama event emit tetiklenmiyor.
   - **Fix:** `setState('stock', [...getState('stock'), x])` pattern'i kullanılmalı. Plan'da bu belirtilmemiş.

**Minor:**
3. **Task 3 `setupAutocomplete`— `displayField`/`valueField` API'si**
   - Düz string array'ler için `displayField` gereksiz. API iki farklı kullanım modu sunuyor, kod karmaşıklaşıyor.
   - Mevcut `acDisease` sadece string array kullanıyor. API'yi sadeleştirmek daha iyi olabilir.

4. **Task 4 — `_gebeIds`, `_hastaIds` ne olacak?**
   - Bunlar da `ui.js`'te `/* global */` comment'inde var ama state'e taşınması planlanmamış.
   - Tutarlı olmak için hepsi state'e geçmeli.

**Assessment: With fixes** — Important issue'lar düzeltilirse implementasyona hazır.

---

### Plan 2: Aşama 4+6 Hata + XSS
`2026-05-13-asama4-6-hata-xss.md`

**Strengths:**
- `withErrorHandling` wrapper tasarımı temiz, tüm async çağrıları sarabilir
- `USER_FRIENDLY_ERRORS` haritası pratik
- `esc()` fonksiyonu basit, etkili
- Global `error`/`unhandledrejection` dinleyicileri kapsamlı

**Issues:**

**Important:**
5. **Task 3 — Hangi innerHTML'lerin değişeceği net değil**
   - "Sadece kullanıcı verisi içeren innerHTML'ler" denmiş ama liste verilmemiş
   - 186 innerHTML var (126 ui.js + 33 forms.js + 27 app.js). Hangileri değişecek?
   - **Fix:** `grep -n 'innerHTML.*=.*\$\{' js/ui.js js/forms.js js/app.js | grep -v 'band('` çıktısı plana eklenmeli

6. **`showDebug` fonksiyonu CSS'e ihtiyaç duyar**
   - Plan'da debug panelinin CSS'i yok. `#debugPanel` nerede tanımlanacak?
   - **Fix:** index.html'ye debug panel div'i eklenmeli, CSS'i belirtilmeli

**Minor:**
7. **Task 1 `withErrorHandling` — `throw err` re-throw**
   - Toast gösterdikten sonra re-throw etmek, çağıran tarafta ikinci toast'a sebep olur.
   - **Fix:** `toast`'tan sonra `return null` veya hata objesi dön.

**Assessment: With fixes** — Task 3 scope'unun netleştirilmesi şart.

---

### Plan 3: Aşama 2 Veri Yönetimi
`2026-05-13-asama2-veri-yonetimi.md`

**Strengths:**
- `insertOffline`/`updateOffline` ayrımı doğru
- Exponential backoff (2^retryCount) standart pattern, max 60sn cap iyi
- IndexedDB index'leri performansı ciddi artırır

**Issues:**

**Important:**
8. **Task 1 — `write()` çağrılarının değiştirilmesi riskli**
   - `grep -n "write(" js/ui.js` → hangi satırlar? Plan spesifik değil.
   - `write()` 3 parametre alıyor olabilir mi? Mevcut implementasyonu görmeden değiştirilemez.
   - **Fix:** Önce `write()`'in mevcut imzasını oku, tüm çağrıları listele, sonra planı güncelle.

9. **Task 2 — `syncNow` içinde `setTimeout(() => syncNow(), delay)` recursive**
   - Birden fazla item varsa, her başarısız item için ayrı setTimeout oluşur → race condition
   - **Fix:** Tek bir retry timer'ı olmalı, tüm başarısız item'lar topluca denenmeli

10. **Task 4 — `rpcOptimistic` local update için `setState` kullanıyor**
    - Ama `setState` event emit eder. Render tetiklenir. Optimistic update'te bu istenmeyebilir.
    - **Fix:** `setBatch` kullan veya `silent: true` flag'i ekle.

**Assessment: With fixes** — Özellikle task 1 (write çağrıları) ve task 2 (race condition) çözülmeli.

---

### Plan 4: Aşama 5 Migration
`2026-05-13-asama5-migration.md`

**Strengths:**
- Net ve küçük kapsam
- Idempotent kontrolleri pratik (grep ile tarama)
- Ground truth migration referans amaçlı — çalıştırılmayacak

**Issues:**

**Minor:**
11. **Task 1 — `ARCHITECTURE.md` dosyası yoksa?**
    - `grep ARCHITECTURE.md 2>/dev/null` var ama dosya yoksa plan ne yapacak?
    - **Fix:** "ARCHITECTURE.md bulunamazsa bu task atlanır" notu ekle.

12. **Task 3 — `cat supabase/migrations/20*.sql > ground_truth.sql`**
    - Migration'lar sırası önemli. `20*` ile başlayan tüm dosyalar var mı? Yoksa `cat` başarısız olur.
    - **Fix:** `ls supabase/migrations/*.sql | sort | xargs cat > ...` daha güvenli.

**Assessment: Ready** — Minor fix'lerle.

---

### Plan 5: Aşama 3 UI
`2026-05-13-asama3-ui.md`

**Strengths:**
- Event delegation pattern doğru — `closest('[data-action]')` ile bubbling
- `registerAction` API'si temiz
- "Modal sınıfları ayrı plan" diyerek scope creep'i engelliyor

**Issues:**

**Important:**
13. **Task 1 — 212 onclick değişikliği için bir strateji yok**
    - "Tüm onclick'leri sil, data-action koy" — 212 yerde elle değişiklik riskli
    - Hangi butonlar hangi handler'a bağlanacak? Kayıp handler = buton sessizce çalışmaz
    - **Fix:** Önce `grep -oPn 'on\w+="([^"]*)"' index.html` ile tüm handler'ları listele, her birini map'le

14. **Task 1 — `data-action-input` ve `data-action-change` gereksiz karmaşık**
    - `data-action="filter-animals"` ve `data-action-event="input"` daha sade olur
    - 3 farklı attribute (action, action-input, action-change) yerine tek attribute + event tipi

15. **Task 2 — Toast mesajları CSS ile stack edilmeli**
    - `nth-child(2)`, `nth-child(3)` her toast eklendikçe index değişir → yanlış konumlandırma
    - **Fix:** Toast container div'i + flexbox column kullan

**Assessment: Needs work** — Task 1 için detaylı handler listesi şart.

---

### Plan 6: Aşama 7+8+9 Performans+Test+Döküman
`2026-05-13-asama7-8-9-performans-test-dokuman.md`

**Strengths:**
- Debounce/throttle basit ve etkili
- ESLint globals tanımı kapsamlı (g, v, cl, toast, getState...)
- README yapısı net

**Issues:**

**Minor:**
16. **Task 1 — `debounce(pullTables, 5000)` → mevcut debounce'ı eziyor mu?**
    - `ui.js`'te zaten `renderSafe` debounce'u var (60ms). `pullTables`'ın da kendi debounce'u olabilir.
    - **Fix:** Önce mevcut debounce'ları kontrol et, conflict varsa merge et.

17. **Task 2 — `.eslintrc.json`'da `ecmaVersion: 2020`**
    - `index.html`'deki JS'ler module değil, global scope. `optional chaining (?.)` kullanılıyor (bkz: `g(id)?.value`)
    - EcmaVersion 2020 optional chaining'i kapsar → OK. Ama `.eslintrc` yerine flat config (`eslint.config.js`) daha modern.

**Assessment: Ready** — Minor fix'lerle.

---

## Özet: Tüm Planlar

| Plan | Durum | Kritik Sorun |
|------|-------|-------------|
| Plan 1 (Aşama 1) | ⚠️ Fix gerek | Task 1-2 index.html 2 commit'e bölünmüş, state array mutation |
| Plan 2 (Aşama 4+6) | ⚠️ Fix gerek | innerHTML scope net değil, debug panel CSS yok |
| Plan 3 (Aşama 2) | ⚠️ Fix gerek | write() imzası bilinmeden değiştirilemez, syncNow race |
| Plan 4 (Aşama 5) | ✅ Hazır | ARCHITECTURE.md kontrolü ekle |
| Plan 5 (Aşama 3) | 🔴 Revize | 212 onclick için strateji ve liste yok |
| Plan 6 (Aşama 7-9) | ✅ Hazır | Mevcut debounce'lar kontrol edilsin |

---

## Öneri: Hemen Başlanabilecekler

1. **Plan 4 (Aşama 5)** — Bağımsız, küçük, risksiz
2. **Plan 6 (Aşama 7-9)** — Bağımsız (debounce kontrolüyle)

## Revize Gerektirenler

3. **Plan 1** — 2 fix sonrası (index.html sırası, state mutation)
4. **Plan 2** — innerHTML scope netleştikten sonra
5. **Plan 3** — write() çağrıları listelendikten sonra
6. **Plan 5** — onclick handler listesi çıkarıldıktan sonra
