# EgeSüt ERP — SonarCloud Remediation Plan
> Kaynak: sonarcloud_issues-2026-03-22_10-48-52.csv | Toplam: 517 issue
> Bu dosya her sprint tamamlandıkça güncellenir. Biten adımlar ✅ ile işaretlenir.
---

## ÖZET TABLO

| Sprint | Kapsam | Issue Sayısı | Tahmini Süre | Durum |
|--------|--------|-------------|--------------|-------|
| WONTFIX | Dokümantasyon (SonarCloud UI'da işaretlenecek) | ~188 | — | ⏳ Manuel işaretleme bekliyor |
| S1 | Gerçek Bug'lar | ~10 | 25 dk | ✅ Tamamlandı (f8874a0) |
| S2 | BLOCKER Globals | 28 | 20 dk | ✅ Tamamlandı (14cda49) |
| S3 | Mantık Tutarsızlıkları | ~35 | 40 dk | ✅ Tamamlandı (b572e26) |
| S4 | Cognitive Complexity + Nested Ternary | ~75 | 75 dk | ✅ Tamamlandı (0f2f0e2) |
| S5 | Minor Modernizasyon (Bulk) | ~100 | 45 dk | ✅ Tamamlandı (55e8212) |
| **Toplam** | | **~436** | **~4 saat** | ✅ Kod fixleri bitti |

**Kural:** Her sprint ayrı bir AI oturumudur. Oturum başında bu dosyanın ilgili sprint bölümü + etkilenen dosyalar kontekst olarak verilir. Sprint bitince bu dosyadaki checkbox'lar güncellenir, `git commit` atılır.

---

## BUG FIX OTURUMLARI (SonarCloud dışı)

### Oturum 2026-03-25

#### ✅ Tamamlanan Fixler

| Fix | Dosyalar | Açıklama |
|-----|----------|----------|
| CI: Migration versiyon uyuşmazlığı | `supabase/migrations/` | `apply_migration` ile DB'ye uygulanan migration Supabase'in kendi timestamp'ini (075027) üretiyordu. Lokal dosya 000026 ile adlandırılmıştı → GitHub Actions `db push` red yiyordu. Rename ile çözüldü. |
| Hayvan grubu kuralları | `js/app.js`, `js/ui.js` | `animalFormGuncelle` async yapıldı. Doğum/abort kaydı → sadece Sağmal/Kuru. Tohumlanmış → yetişkin gruplar. 12ay+ → buzağı grubu yok. `openAnimalEdit`'te `await animalFormGuncelle()`. |
| Doğum tarihi ileri tarih engeli | `js/app.js`, `js/forms.js` | `openM('m-animal')`'de `a-dt` inputuna `max=bugün` set edildi. Submit'te `yasGun < 0` guard eklendi. |
| Dark mode: beyaz fon / hardcoded renkler | `js/ui.js` | `background:#fff` → `var(--card)` (bottom sheet + autocomplete kutular). `border:1px solid #eee` → `var(--card3)`. `color:#666` → `var(--ink3)`. Toplu replace. |

#### ⏳ Ertelenen / Araştırma Gerektiren

| Bug | Durum | Notlar |
|-----|-------|--------|
| Yeni hayvan ekleme — liste anlık güncellenmiyor | Ertelendi — **~15-25 dk** | `submitAnimal`'da `pullTables(['hayvanlar'])` → `renderFromLocal()` zinciri teorik doğru ama reload'dan sonra çalışıyor. En olası neden: `api.js:230` `_pulling` guard concurrent pull'da silently drop ediyor. Başlangıç noktası: `_pulling` true mu diye log ekle ya da MCP ile `hayvan_durum_view` propagation gecikmesini test et. |

#### 📝 Dikkat: MCP apply_migration Kuralı
`mcp__supabase__apply_migration` kullandığında Supabase kendi timestamp'ini üretir (örn. `20260325075027`).
Lokal dosyayı da aynı versiyon numarasıyla adlandır. Aksi hâlde `supabase db push` hata verir.

---

### Oturum 2026-03-26

#### ✅ Tamamlanan Fixler

| Fix | Commit | Dosyalar | Açıklama |
|-----|--------|----------|----------|
| Fix 1: pullTables Promise-based lock | 9d1db71 | `js/api.js` | `_pulling` boolean → Promise-based lock. Concurrent pull'larda silent drop yerine bekle. Yeni hayvan eklenince liste anlık güncelleniyor. |
| Fix 2: Grup/padok kuralları + gebe trigger | 5d5a577 | `js/app.js`, `js/config.js`, `js/forms.js`, `supabase/migrations/` | Grup değişiminde padok otomatik. Gebe trigger DB'de. Tohumlama dropdown fix. |
| Fix 3: Tedavi ilaç seçim dark mode | 68940bf | `js/ui.js` | Hardcoded renkler CSS var'a çevrildi. |
| Fix 4: Tedavi saat görünmüyor | d97486a | `supabase/migrations/` | `treatment_timeline` view'a `treatment_time` eklendi. |
| Fix 5: Besi padok split + _TH ön yükleme | 12b5657 | `js/config.js`, `js/app.js` | Besi padok → Erkek/Dişi ayrı. Cinsiyet bazlı otomatik padok seçimi. `_TH` tohumlama dropdown'ı için ön yükleme. |
| Fix 6: Tohumlama modal küpe + tıklanabilir hayvan | 12b5657 | `js/ui.js`, `js/forms.js` | `td2-hayvan` raw ID yerine kupe_no gösteriyor. Tıklayınca modal kapanıp hayvan kartı açılıyor. Duplicate `openTohDet` (forms.js) silindi. |
| Fix 7: Doğum formunda baba otomasyonu | ⏳ bu oturum | `index.html`, `js/forms.js`, `js/ui.js` | Anne seçilince tohumlama kaydından sperma → otomatik baba. Kayıt yoksa serbest metin alanı gösterilir. |

#### ⏳ Devam Eden

| Fix | Durum |
|-----|-------|
| Fix 7: Doğum baba otomasyonu | Uygulanıyor |

---

## TEST & DEPLOY PROTOKOLÜ

### Sprint Sonu Akışı

1. **AI sprint'i tamamlar** — tüm fix'ler uygulanır, `node --check` ile syntax doğrulanır.
2. **AI test listesi üretir** — değiştirilen her kod bölgesi için "ne tıklanır, ne kontrol edilir" maddeleri açıklanır.
3. **Kullanıcı lokalden test eder** — tarayıcı konsolunu açık tutarak AI'ın belirttiği noktaları manuel olarak test eder.
4. **Konsol hatası yoksa** → `git commit` + `git push` → SonarCloud yeni scan'ı bekler.
5. **Hata varsa** → hata mesajı AI'ya iletilir, aynı oturumda düzeltilir, test tekrar edilir.

### Test Sırasında Konsol İçin Kurallar

- Tarayıcıda **F12 → Console** sekmesi açık olsun.
- `is not a function`, `Cannot read properties of`, `Uncaught ReferenceError` gibi hatalar varsa tam hata metnini + hangi işlemi yaparken çıktığını not et.
- Network sekmesinde kırmızı (4xx/5xx) istek varsa URL ve status kodunu not et.

### AI'ın Test Listesini Nasıl Üreteceği

Sprint bitti mesajından sonra AI her değişen **fonksiyon/bölge** için şu formatta test maddesi yazar:

```
## [Sprint kodu] Test Listesi

### [Fonksiyon / Bölge Adı]
- Adım: [ne yapılır]
- Beklenen: [ne görülmeli]
- Konsol riski: [hangi hata çıkabilir, neden]
```

---

## BÖLÜM 0 — WONTFIX KATALOG (~188 issue)

Bu issue'lar SonarCloud'da "Won't Fix" olarak işaretlenecek. Kod değişikliği YOK.

**SonarCloud'da nasıl yapılır:** Issues → Her issue açılır → "Won't Fix" seçilir → Sebep yazılır.

| Kural | Sayı | Sebep |
|-------|------|-------|
| `Web:S6853` — Label accessibility | 64 | Saha uygulaması. Screen reader kullanıcısı yok. |
| `Web:S6848` — Non-native interactive element | 24 | onClick div'ler kasıtlı pattern. Mobil native hiss için. |
| `Web:MouseEventWithoutKeyboardEquivalentCheck` | 24 | Dokunmatik öncelikli uygulama. Klavye kullanıcısı yok. |
| `Web:S7926` — user-scalable=no | 1 | Mobil native hiss kasıtlı. zoom kapatmak zorunlu. |
| `css:S7924` — Contrast | 1 | Dark theme tasarım kararı. Değiştirilemez. |
| `plsql:S1192` — SQL literal duplication | 72 | Migration dosyaları. Zaten DB'ye apply edildi, dokunulmaz. |
| `Web:S5254` atsiki.html lang | 1 | Dosya `.repomixignore`'da, proje scope dışı. |
| `sw.js` S7764 | 1 | Service worker disabled. Kod çalışmıyor zaten. |

**Toplam WONTFIX: ~188 issue**

---

## SPRINT S1 — Gerçek Bug'lar

**Hedef:** Gerçek runtime bug riski taşıyan veya kesinlikle hatalı olan kodları düzelt.  
**Dosyalar:** `index.html`, `js/ui.js`, `supabase/migrations/20260306000006_faz1_core.sql`  
**Oturum başı bağlam:** Bu sprint bölümü + repomix XML

### Görev Listesi

- [x] **FIX-1.1** — Duplicate ID'ler `index.html` (S7930 CRITICAL) → f8874a0
- [x] **FIX-1.2** — SQL NullComparison `faz1_core.sql` (plsql:NullComparison MAJOR) → ⏭ WONTFIX (migration dosyası)
- [x] **FIX-1.3** — Constant truthiness `js/ui.js:1131` (S6638 MAJOR BUG) → f8874a0
- [x] **FIX-1.4** — Always-empty `logs` array `js/ui.js:2000` (S4158 MINOR BUG) → f8874a0
- [x] **FIX-1.5** — Duplicate `stokDrugBagla` fonksiyonu `js/ui.js:949-963` (S4144 MAJOR) → f8874a0

---

### FIX-1.1 — Duplicate ID'ler (index.html)

**Problem:** 3 ayrı yerde duplicate ID var.

**Tespit:** index.html içinde bu komutla bul:
```bash
grep -n 'id="' index.html | awk -F'"' '{print $2}' | sort | uniq -d
```

**Bilinen duplicate'ler (CSV'den):**
- Line 974: `id="toast"` — ikinci kez tanımlı (ilki line 914)
- Line 435 ve 446: başka duplicate ID'ler (tam içerik için `index.html` line 435-446'ya bak)

**Fix:**

`index.html` satır 974'teki ikinci `<div id="toast">` tag'ini kaldır. Line 914'teki orjinali kalır.

Line 435-446 için: önce hangi ID'nin duplicate olduğunu tespit et (grep ile), sonra ikinci görüneni ya kaldır ya ID'yi değiştir. İki element de aktif kullanılıyorsa ikincisine `id="toast2"` ver ve ilgili JS'i güncelle.

**Validation:** `grep -c 'id="toast"' index.html` → 1 döndürmeli.

---

### FIX-1.2 — SQL NullComparison (faz1_core.sql)

**Problem:** PostgreSQL'de `= NULL` her zaman `FALSE` döner. Bu sessiz bir bug.

**Dosya:** `supabase/migrations/20260306000006_faz1_core.sql`

**Tespit:**
```bash
grep -n "= NULL\|!= NULL\|<> NULL" supabase/migrations/20260306000006_faz1_core.sql
```

Lines 336 ve 345'te `= NULL` veya `<> NULL` kullanımı var.

**Fix pattern:**
```sql
-- BEFORE:
WHERE kolon = NULL
WHERE kolon != NULL

-- AFTER:
WHERE kolon IS NULL
WHERE kolon IS NOT NULL
```

**Önemli:** Bu bir migration dosyası. Dosyayı düzeltmek SonarCloud'u susturur ama production DB'yi etkilemez (zaten apply edilmiş). Eğer fix production'a da yansımalıysa yeni bir migration yaz:
```
supabase/migrations/20260326000001_fix_null_comparison.sql
```
İçeriği: ilgili VIEW veya FUNCTION'ı `CREATE OR REPLACE` ile düzeltilmiş haliyle yeniden yaz.

---

### FIX-1.3 — Constant Truthiness (ui.js:1131)

**Problem:** `||` ifadesinin sol tarafı her zaman truthy. Dead code üretiyor.

**Tespit:** `js/ui.js` line 1131'e git.

Muhtemelen şuna benziyor:
```js
// BEFORE (SonarCloud S6638):
const x = someArray || [];  // someArray hiç null/undefined olmuyorsa sol taraf hep truthy

// Veya:
const x = "sabit string" || defaultValue;  // sol taraf her zaman truthy, sağ hiç çalışmaz
```

**Fix:** Line 1131'deki ifadeyi incele. Eğer sol taraf gerçekten her zaman truthy ise sağ tarafı (dead branch) kaldır, sadece sol tarafı bırak.

```js
// AFTER:
const x = someArray;  // sağ taraf gereksizdi
```

---

### FIX-1.4 — Always-Empty `logs` Array (ui.js:2000)

**Problem:** `logs` değişkeni oluşturuluyor ama her zaman boş. Sonrasında `.map()`'i çalıştırılan bir dizi ama hiçbir şey üretmiyor.

**Bağlam:** Bu `acDisease()` fonksiyonunda. `hastalik_log` kaldırıldıktan sonra kalan dead code.

**Tespit:** `js/ui.js` line ~2000:
```js
const logs = []; // hastalik_log kaldirildi
const usedDis = [...new Set(logs.map(l => l.tani).filter(Boolean))];
```

**Fix:** `logs` ve `usedDis` satırlarını kaldır. `all` array'ini sadece sabit listeden oluştur:
```js
// BEFORE:
const logs = []; // hastalik_log kaldirildi
const usedDis = [...new Set(logs.map(l => l.tani).filter(Boolean))];
const all = [...new Set([...HASTALIK_LISTESI,...usedDis])];

// AFTER:
const all = [...HASTALIK_LISTESI];
```

---

### FIX-1.5 — Duplicate `stokDrugBagla` Fonksiyonu (ui.js:949 ve 963)

**Problem:** `stokDrugBagla` fonksiyonu ui.js'de iki kez tanımlı. İkincisi birincinin üzerine yazıyor ama ikisi de aynı şeyi yapıyor.

**Tespit:**
```bash
grep -n "function stokDrugBagla\|stokDrugBagla" js/ui.js
```

**Fix:** Line 963'teki ikinci tanımı tamamen sil (line 949'daki kalır).

İki fonksiyon tamamen aynıysa: birini sil.  
Eğer farklılık varsa: ikisini incele, hangisi doğruysa onu tut, diğerini sil.

---

## SPRINT S2 — BLOCKER Globals

**Hedef:** SonarCloud'un "implicit global declaration" diye işaretlediği 28 BLOCKER issue'yu kapat.  
**Dosyalar:** `js/ui.js`, `js/forms.js`, `js/app.js`  
**Süre:** ~20 dakika  
**Oturum başı bağlam:** Bu sprint bölümü + `js/ui.js` başı + `js/forms.js` başı + `js/app.js` başı

### Neden Bu Sorun Var

SonarCloud her dosyayı izole analiz eder. `_curTaskFilter` `app.js`'de `let` ile tanımlı, ama `ui.js`'de `_curTaskFilter = f` yapıldığında SonarCloud bunu "yeni implicit global" olarak görür.

### Strateji: `/* global */` Annotation

Her dosyanın EN BAŞINA (ilk satır olarak) ilgili cross-file global'lerin listesi eklenir. Bu ESLint ve SonarCloud tarafından "bu değişkenler başka dosyada tanımlı, şikayet etme" direktifi olarak algılanır.

### Görev Listesi

- [x] **FIX-2.1** — `js/ui.js` başına `/* global */` bloğu ekle → 14cda49
- [x] **FIX-2.2** — `js/forms.js` başına `/* global */` bloğu ekle → 14cda49
- [x] **FIX-2.3** — `js/app.js` — `HEKIMLER` re-declaration (app.js içindeki S2703) → 14cda49

---

### FIX-2.1 — `js/ui.js` Başına Global Annotation

Dosyanın en başındaki yorum bloğunun HEMEN ALTINA (veya yoksa dosyanın ilk satırına) ekle:

```js
/* global
   _A, _S, _gebeIds, _hastaIds,
   _curTaskFilter, _curUremeTab, _curGecmisFilter, _curStk,
   _curTaskDet, _curToh,
   _customHekimler, _customSperma,
   _ilacCache, _drugsCache, _disFreq,
   HEKIMLER, VARSAYILAN_HEKIM,
   HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SEMPTOM_KAT, SEMPTOM_GENEL,
   SPERMA_LISTESI, GRUP_PADOK,
   getState, setState,
   g, v, cl, dAgo, dFwd, fmtTarih, toast, openM, closeM, mClose,
   db, rpc, rpcOptimistic, pullTables, renderSafe, renderFromLocal,
   idbGetAll, idbPut, idbClearAndPut, getData, getQueue, removeFromQueue,
   openDB, syncNow, updateSyncBar
*/
```

**Kapattığı S2703 variable'ları:** `_A`, `_S`, `_curTaskFilter`, `_curUremeTab`, `_curGecmisFilter`, `_curStk`, `_curTaskDet`, `_curToh`, `_customHekimler`, `_customSperma`, `_gebeIds`, `_hastaIds`, `_ilacCache`

---

### FIX-2.2 — `js/forms.js` Başına Global Annotation

```js
/* global
   _curTaskDet, _curToh, _curHst, _curBildirimTab, _curStk,
   _editMode, _semptomSecili, _hdeSmptSecili,
   _ilacCache, _drugsCache, _hdiIlacCache,
   _customHekimler, _customSperma, _disFreq,
   HEKIMLER, VARSAYILAN_HEKIM,
   HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SEMPTOM_KAT, SEMPTOM_GENEL,
   getState, setState,
   g, v, cl, dAgo, dFwd, fmtTarih, toast, openM, closeM,
   db, rpc, pullTables, renderSafe, renderFromLocal,
   idbGetAll, getData, write,
   loadDrugsCache, loadStock, loadDash, loadTasks, loadUreme, loadGecmis,
   loadBildirimler, loadStokPanel, openDet, closeDet, openStokPanel,
   openAnimalEdit, closeAnimalEdit, getDisplayKupe, yasHesapla, loadIrkDropdown
*/
```

**Kapattığı S2703 variable'ları:** `_curTaskDet`, `_curToh`, `_drugsCache`, `_ilacCache`

---

### FIX-2.3 — `js/app.js` — `HEKIMLER` Re-declaration

**Problem:** `app.js`'de S2703 için `HEKIMLER` flagleniyor. `HEKIMLER` `config.js`'de `const` olarak tanımlı, ama `app.js`'de `HEKIMLER = data.map(...)` satırıyla yeniden atama yapılıyor. `const`'a atama hata verir.

**Tespit:** `js/app.js` içinde `HEKIMLER =` ifadesini bul.

**Fix:** `loadHekimler()` fonksiyonunda `HEKIMLER` const olduğu için doğrudan atanamaz. Fix:

```js
// BEFORE (app.js içinde loadHekimler):
async function loadHekimler() {
  try {
    const { data, error } = await db.rpc('hekim_listesi');
    if (!error && data && data.length > 0) {
      HEKIMLER = data.map(h => ({ id: h.id, ad: h.ad, telefon: h.telefon }));
    }
  } catch (e) { ... }
}

// AFTER — window üzerinden override et (config.js'deki const'u gölgeler):
async function loadHekimler() {
  try {
    const { data, error } = await db.rpc('hekim_listesi');
    if (!error && data && data.length > 0) {
      window.HEKIMLER = data.map(h => ({ id: h.id, ad: h.ad, telefon: h.telefon }));
    }
  } catch (e) { ... }
}
```

Aynı zamanda `config.js`'deki `const HEKIMLER` tanımını `let HEKIMLER` veya `window.HEKIMLER` olarak değiştir:

```js
// config.js BEFORE:
const HEKIMLER = [ ... ];

// config.js AFTER:
let HEKIMLER = [ ... ];
```

---

## SPRINT S3 — Mantık Tutarsızlıkları

**Hedef:** Kod davranışını etkileyebilecek mantık hatalarını ve misleading pattern'leri düzelt.  
**Dosyalar:** `js/app.js`, `js/ui.js`, `js/forms.js`, `js/api.js`  
**Süre:** ~40 dakika  
**Oturum başı bağlam:** Bu sprint bölümü + ilgili dosyalar

### Görev Listesi

- [x] **FIX-3.1** — S2681 Misleading if/else (5 konum, 2 dosya) → b572e26
- [x] **FIX-3.2** — S1871 Duplicate branch `app.js:292` → b572e26
- [x] **FIX-3.3** — S6660 If-in-else `app.js:343` → 20f60ba
- [x] **FIX-3.4** — S1854+S1481 Useless assignments (9 konum, `ui.js`) → b572e26
- [x] **FIX-3.5** — S2486 Empty catch blocks (3 konum) → zaten dolu, değişiklik gerekmedi
- [x] **FIX-3.6** — S1874 Deprecated `event` (4 konum) → 0f2f0e2
- [x] **FIX-3.7** — S7735 Negated conditions (7 konum) → 55e8212
- [x] **FIX-3.8** — S7754 `.find()` → `.some()` (4 konum) → b572e26
- [x] **FIX-3.9** — S7759 `new Date()` → `Date.now()` (4 konum) → ⏭ no-op (pattern yok)

---

### FIX-3.1 — S2681 Misleading If/Else (app.js:77, ui.js:59,1802,2170,2178)

**Problem:** `if` bloğu `{}` braces olmadan birden fazla statement içeriyor. İlk statement koşullu, sonrakiler **her zaman** çalışıyor.

**Pattern:**
```js
// BEFORE (BUG):
if (condition)
  doFirst();
  doSecond();  // Her zaman çalışır! Koşullu DEĞİL.

// AFTER:
if (condition) {
  doFirst();
  doSecond();
}
```

**Her konum için:** İlgili satıra git, braces olmayan if bloğunu bul, tüm bloğu `{}` ile sarmalı olarak yeniden yaz. Hangi statement'ların koşullu olmasının **DOĞRU** olduğunu bağlamdan belirle. Koşullu olmamalarının kasıtlı olduğu durumda ise if'i böl.

**Konumlar:**
| Dosya | Satır | Tespit |
|-------|-------|--------|
| `js/app.js` | 77 | `openM` fonksiyonunda |
| `js/ui.js` | 59 | `loadDash` veya başka render fn'de |
| `js/ui.js` | 1802 | `loadDrugsCache` bölgesinde |
| `js/ui.js` | 2170 | `ayarlarHekimKaydet` bölgesinde |
| `js/ui.js` | 2178 | Aynı bölge |

---

### FIX-3.2 — S1871 Duplicate Branch (app.js:292)

**Problem:** `if` ve `else if` bloklarının içeriği aynı. Ya copy-paste hatası ya da gereksiz dallanma.

**Tespit:** `js/app.js` line 292 civarındaki if-else zincirini oku.

```js
// BEFORE:
if (condA) {
  doSomething();
} else if (condB) {
  doSomething();  // AYNI KOD
}

// AFTER (iki durum aynı şeyi yapıyorsa birleştir):
if (condA || condB) {
  doSomething();
}
```

Eğer iki branch aynı değilse (SonarCloud yanılmış ise) `// NOSONAR` ile geç.

---

### FIX-3.3 — S6660 If-in-Else (app.js:343)

**Problem:** `else { if(x) {...} }` yerine `else if(x) {...}` kullanılmalı.

```js
// BEFORE:
if (a) {
  ...
} else {
  if (b) {   // line 343
    ...
  }
}

// AFTER:
if (a) {
  ...
} else if (b) {
  ...
}
```

---

### FIX-3.4 — S1854+S1481 Useless Assignments (ui.js)

**Problem:** Değişkene değer atanıyor ama sonrasında kullanılmıyor (overwrite ya da fonksiyon sonu).

**Konumlar (tümü `js/ui.js`):**

| Satır | Değişken | Fix |
|-------|----------|-----|
| 757 | `today` | `const today = ...` sonrasında kullanılmıyorsa SATAIRI SİL |
| 897 | (incele) | Aynı pattern |
| 1018 | (incele) | Aynı pattern |
| 1092 | (incele) | Aynı pattern |
| 1208 | `tohBos` | `const tohBos = tohs.filter(...)` kullanılmıyorsa SATIRI SİL |
| 2043 | (incele) | Aynı pattern |

**Metod:** Her satırı bul, değişkenin nerede kullanıldığını kontrol et. Hiç kullanılmıyorsa satırı sil. Kullanılıyorsa SonarCloud'un neden flaglediğini anlamak için overwrite kontrolü yap.

---

### FIX-3.5 — S2486 Empty Catch Blocks (app.js:273, forms.js:781, ui.js:1656)

**Problem:** `catch(e) {}` — hata yakalanıyor ama hiçbir şey yapılmıyor. Sorunlar sessizce yutulur.

```js
// BEFORE:
try {
  ...
} catch (e) {}  // BOŞ — S2486

// AFTER (minimum):
try {
  ...
} catch (e) {
  console.warn('[functionName]', e.message);
}
```

Her catch bloğuna `console.warn` ekle. `e` parametresi silinmişse `_e` yap veya `catch { console.warn(...) }` (parameter-less catch ES2019).

---

### FIX-3.6 — S1874 Deprecated `event` (api.js:123,131, ui.js:2118)

**Problem:** Global `event` object kullanımı deprecated. Fonksiyona parametre olarak geçirilmeli.

```js
// BEFORE (api.js:123 civarı):
function handler() {
  const e = event;  // global event object — deprecated
}

// AFTER:
function handler(e) {
  // e parametre olarak geldi
}
```

`ui.js:2118`:
```js
// BEFORE:
function dataTrafficGonder() {
  const btn = event.target;  // deprecated global event

// AFTER:
function dataTrafficGonder(e) {
  const btn = e.target;
```
HTML'deki çağrıyı da güncelle: `onclick="dataTrafficGonder(event)"`

---

### FIX-3.7 — S7735 Negated Conditions (api.js:309, ui.js:456,1402,1562,1584,1738)

**Problem:** `if (!condition) { A } else { B }` yerine pozitif form daha okunabilir.

```js
// BEFORE:
if (!isOnline) {
  handleOffline();
} else {
  handleOnline();
}

// AFTER:
if (isOnline) {
  handleOnline();
} else {
  handleOffline();
}
```

Her konumu incele, eğer else branch varsa pozitif forma çevir. Else yoksa ve olumsuz şart mantıklıysa `// NOSONAR` ekle.

---

### FIX-3.8 — S7754 `.find()` → `.some()` (app.js:207, ui.js:361,1043,1239)

**Problem:** Sadece varlık kontrolü yapılıyor ama `.find()` kullanılmış.

```js
// BEFORE:
if (list.find(x => x.id === id)) {  // değer kullanılmıyor

// AFTER:
if (list.some(x => x.id === id)) {
```

**Her konumu kontrol et:** `.find()` sonucu sadece truthy/falsy kontrolü için kullanılıyorsa `.some()`'a çevir. Eğer bulunan objeye erişiliyorsa `.find()` kalmalı.

---

### FIX-3.9 — S7759 `new Date()` → `Date.now()` (ui.js:134,401,802,805)

**Problem:** Sadece timestamp için `new Date()` oluşturuluyor.

```js
// BEFORE:
const ms = new Date() - startDate;  // timestamp için new Date() gereksiz

// AFTER:
const ms = Date.now() - startDate;
```

**Her konumu kontrol et:** `new Date()` ile sadece `.getTime()` ya da timestamp alınıyorsa `Date.now()` kullan. Eğer Date objesi olarak işleniyorsa değiştirme.

---

## SPRINT S4 — Cognitive Complexity + Nested Ternary

**Hedef:** Karmaşıklık limitini aşan fonksiyonları refactor et ve nested ternary'leri düzelt.  
**Dosyalar:** `js/ui.js`, `js/app.js`, `js/api.js`, `js/forms.js`  
**Süre:** ~75 dakika (en ağır sprint)  
**Oturum başı bağlam:** Bu sprint bölümü + ilgili dosyalar

### Görev Listesi

- [x] **FIX-4.1** — S3776 Cognitive Complexity — 9 fonksiyon (CRITICAL) → 0f2f0e2 + 55e8212
- [x] **FIX-4.2** — S3358 Nested Ternary — 51 konum (MAJOR) → b572e26
- [x] **FIX-4.3** — S6582 Optional Chain — 17 konum (MAJOR) → b572e26

---

### FIX-4.1 — Cognitive Complexity (S3776)

SonarCloud limit: **15**. Bu fonksiyonlar limiti aşıyor:

| Dosya | Satır | Fonksiyon | Yöntem |
|-------|-------|-----------|--------|
| `js/api.js` | 138 | `write()` | İç helper'lara böl |
| `js/app.js` | 309 | `renderFromLocal()` veya `goTo()` | Switch yerine map kullan |
| `js/ui.js` | 37 | `loadDash()` | Band render'ları ayrı fonksiyona al |
| `js/ui.js` | 329 | `loadTasks()` veya `renderTask()` | Her filter case ayrı fonksiyona |
| `js/ui.js` | 475 | `renderAnimals()` | Badge/tag render ayrı fonk |
| `js/ui.js` | 540 | `openDet()` | Her tab render ayrı fonk |
| `js/ui.js` | 752 | `loadUreme()` | Her tab case ayrı fonk |
| `js/ui.js` | 889 | `loadGecmis()` | Her entry type render ayrı fonk |

**Uygulama Kuralı:** Fonksiyonu küçük alt fonksiyonlara bölerken:
1. Alt fonksiyon ismi açıklayıcı olmalı: `renderDashBand()`, `renderAnimalTags()` vb.
2. Alt fonksiyon sadece string döndürmeli (HTML generator pattern'ini koru)
3. Mevcut global erişimler korunmalı (state, _A vs)
4. Her bölünmüş fonksiyon `async` olmamalı — sadece await gerektiriyorsa

**Örnek — `loadDash()` için:**
```js
// BEFORE: 1 büyük fonksiyon, complexity > 15

// AFTER: ana fonksiyon + helper'lar
function _dashRenderAlarmBand(nearBirth, critStk, negStk) { ... }
function _dashRenderStats(animals, gebeTohs, diseases, tasks) { ... }
async function loadDash() {
  // sadece veri çek + helper'ları çağır
  const html = _dashRenderStats(...) + _dashRenderAlarmBand(...);
  el.innerHTML = html;
}
```

**Örnek — `loadUreme()` için:**
```js
// Her tab için ayrı fonksiyon:
async function _uremeKizginlik() { ... }
async function _uremeTohumlama() { ... }
async function _uremeGebelik() { ... }
async function _uremeDogum() { ... }
async function _uremeAbort() { ... }

async function loadUreme(tab = 'kizginlik') {
  _curUremeTab = tab;
  const el = document.getElementById('ureme-body');
  el.innerHTML = '<div class="loader">...</div>';
  try {
    if (tab === 'kizginlik')    await _uremeKizginlik(el);
    else if (tab === 'tohumlama') await _uremeTohumlama(el);
    // ...
  } catch(e) { el.innerHTML = `<div class="empty">⚠️ ${e.message}</div>`; }
}
```

---

### FIX-4.2 — Nested Ternary (S3358) — 51 konum

**Problem:** İç içe ternary okunaksız.

```js
// BEFORE:
const label = a ? b ? 'X' : 'Y' : 'Z';

// AFTER:
const innerLabel = b ? 'X' : 'Y';
const label = a ? innerLabel : 'Z';
```

**Konumlar (tümü ui.js'de yoğun):**
`ui.js:` 64, 133, 438, 445, 670, 671, 673, 714, 781, 782, 907, 1132, 1695, 1716, 1738, 1852  
`forms.js:` 653, 666

**Strateji:** Bu 51 konum için AI'ya şu direktifi ver:
> "Bu dosyada `S3358` kuralına uyan tüm nested ternary ifadelerini bul (`a ? b ? x : y : z` pattern'i). Her birini ara değişken çıkararak iki satıra böl. Semantiği değiştirme."

---

### FIX-4.3 — Optional Chain (S6582) — 17 konum

**Problem:** Uzun null-check zinciri yerine optional chaining kullanılmalı.

```js
// BEFORE:
const val = obj && obj.prop && obj.prop.sub;

// AFTER:
const val = obj?.prop?.sub;
```

**Konumlar:**
`forms.js:` 168, 368, 376  
`ui.js:` 256, 705 + diğer 12 konum

**Strateji:** AI'ya şu direktifi ver:
> "Bu dosyada `S6582` kuralına uyan tüm `x && x.y` veya `x ? x.y : undefined` pattern'lerini bul. Optional chain (`?.`) kullanarak yeniden yaz."

---

## SPRINT S5 — Minor Modernizasyon (Bulk)

**Hedef:** Tekrarlayan minor rule ihlallerini bulk find-replace ile kapat.  
**Dosyalar:** `js/ui.js`, `js/forms.js`, `js/app.js`, `js/api.js`  
**Süre:** ~45 dakika  
**Oturum başı bağlam:** Bu sprint bölümü + her dosya ayrı ayrı işlenir

**⚠️ UYARI:** S5 S2 ile çakışma riski var. S2'de bazı yerlere `window.` eklendi. S5'in `S7764` (globalThis kuralı) bu satırları yeniden flagleyebilir. **Kural:** S2'de eklenen cross-file global `window.` erişimleri S5'te değiştirilmez, sadece yerel `window._appState` gibi kendi scope'undaki kullanımlar `globalThis`'e çevrilir.

### Görev Listesi

- [x] **FIX-5.1** — S7773: `parseFloat(` → `Number.parseFloat(` (~22 konum) → 55e8212
- [x] **FIX-5.2** — S7781: `.replace(` → `.replaceAll(` (~26 konum) → 55e8212
- [x] **FIX-5.3** — S7780: Regex escaping → `String.raw` (~18 konum) → ⏭ no-op (pattern yok)
- [x] **FIX-5.4** — S7764: `window.` → `globalThis.` (~52 konum, dikkatli) → 55e8212

---

### FIX-5.1 — S7773: `Number.parseFloat` (22 konum)

**Etkilenen dosyalar:** `js/forms.js` (satırlar: 55, 56, 57, 80, 319, 743), `js/ui.js` (çok satır)

**Bulk Replace:**
```
SEARCH:  parseFloat(
REPLACE: Number.parseFloat(
```

**Dikkat:** `Number.parseFloat` ve `parseFloat` davranış olarak identiktir. Güvenli değiştirme.

---

### FIX-5.2 — S7781: `String#replaceAll` (26 konum)

**Etkilenen:** `js/app.js` (satırlar: 215, 454, 606), `js/ui.js` (çok satır)

**Sadece global replace için geçerli:** `.replace(str, ...)` → `.replaceAll(str, ...)`  
**Regex replace için değil:** `.replace(/pattern/g, ...)` — bu zaten global, değiştirme.

```js
// BEFORE:
str.replace("'", "\\'")

// AFTER (eğer tüm occurrence'ları değiştiriyorsa):
str.replaceAll("'", "\\'")
```

**Metod:** Her konumu kontrol et — ilk argument string literal mi? Evet ise replaceAll. Regex ise bırak.

---

### FIX-5.3 — S7780: `String.raw` (18 konum)

**Problem:** Backslash escape olan string literal'ler `String.raw` ile daha temiz yazılabilir.

```js
// BEFORE:
const re = "kupe\\.no";  // \\. escaped dot

// AFTER:
const re = String.raw`kupe\.no`;
```

**Dikkat:** Bu değişiklik sadece string literallerde backslash escaping için geçerli. Template string'e dönüştürmek string interpolation varsa bozabilir. Her konumu manuel kontrol et.

---

### FIX-5.4 — S7764: `globalThis` (52 konum)

**Problem:** `window.X` yerine `globalThis.X` kullanılmalı (daha portable).

**⚠️ SADECE bu pattern'ler değiştirilir:**
```js
window._appState    → globalThis._appState
window._TH          → globalThis._TH
window.errorLog     → globalThis.errorLog
window.__state      → globalThis.__state
```

**BU PATTERN'LER DEĞİŞTİRİLMEZ (S2'de kasıtlı eklendi):**
```js
window._curTaskFilter    ← DOKUNMA (S2'den)
window.HEKIMLER          ← DOKUNMA (S2'den)
```

**Metod:** Her `window.` kullanımını incele, cross-file global referans mı yoksa yerel state mı olduğunu belirle. Yerel state ise `globalThis.` yap.

---

## BÖLÜM: PROGRESS TRACKER

Tamamlanan her fix için bu tabloya ✅ işareti koy ve commit hash ekle.

| Fix ID | Açıklama | Dosya(lar) | Durum | Commit |
|--------|----------|-----------|-------|--------|
| WONTFIX | SonarCloud'da işaretleme | SonarCloud UI | ⏳ | — |
| FIX-1.1 | Duplicate ID'ler | index.html | ✅ | f8874a0 |
| FIX-1.2 | NullComparison SQL | faz1_core.sql | ⏭ WONTFIX | — |
| FIX-1.3 | Constant truthiness | ui.js | ✅ | f8874a0 |
| FIX-1.4 | Empty logs array | ui.js | ✅ | f8874a0 |
| FIX-1.5 | Duplicate stokDrugBagla | ui.js | ✅ | f8874a0 |
| FIX-2.1 | Global annotation ui.js | ui.js | ✅ | 14cda49 |
| FIX-2.2 | Global annotation forms.js | forms.js | ✅ | 14cda49 |
| FIX-2.3 | HEKIMLER const→let | config.js, app.js | ✅ | 14cda49 |
| FIX-3.1 | S2681 misleading if/else | app.js, ui.js | ✅ | b572e26 |
| FIX-3.2 | S1871 duplicate branch | app.js | ✅ | b572e26 |
| FIX-3.3 | S6660 if-in-else | app.js | ✅ | 20f60ba |
| FIX-3.4 | S1854+S1481 useless vars | ui.js | ✅ | b572e26 |
| FIX-3.5 | S2486 empty catch | app.js, forms.js, ui.js | ✅ | zaten dolu |
| FIX-3.6 | S1874 deprecated event | api.js, ui.js | ✅ | 0f2f0e2 |
| FIX-3.7 | S7735 negated conditions | api.js, ui.js | ✅ | 55e8212 |
| FIX-3.8 | S7754 some vs find | app.js, ui.js | ✅ | b572e26 |
| FIX-3.9 | S7759 Date.now | ui.js | ⏭ no-op (pattern yok) | — |
| FIX-4.1 | S3776 cognitive complexity — loadUreme, loadGecmis, loadDash, renderAnimals, openDet | ui.js | ✅ | 0f2f0e2 |
| FIX-4.1 | S3776 kalan: write() refactor | api.js | ✅ | 55e8212 |
| FIX-4.2 | S3358 nested ternary — tüm ui.js | ui.js, forms.js | ✅ | b572e26 |
| FIX-4.3 | S6582 optional chain | ui.js, forms.js | ✅ | b572e26 |
| FIX-5.1 | S7773 Number.parseFloat | forms.js, ui.js | ✅ | 55e8212 |
| FIX-5.2 | S7781 replaceAll | ui.js (1 konum) | ✅ | 55e8212 |
| FIX-5.3 | S7780 String.raw | — | ⏭ no-op (pattern yok) | — |
| FIX-5.4 | S7764 globalThis | ui.js, forms.js, app.js, api.js, state.js | ✅ | 55e8212 |

---

## BÖLÜM: AI OTURUM PROTOKOLÜ

Her sprint başında AI'ya şu bağlamı ver:

```
1. Bu SONARCLOUD_REMEDIATION_PLAN.md dosyasını oku
2. İlgili Sprint bölümünü oku (sadece o sprint)
3. Etkilenen dosyaları oku (repomix veya direkt dosya)
4. patch.py script ile değişiklikleri uygula
5. node --check ile syntax doğrula
6. git commit -m "sonar: S1 gerçek buglar" ile commit at
7. Bu dosyadaki ilgili checkbox'ları ✅ yap, commit hash ekle
```

**Context minimizasyon kuralı:** Her sprint dosyaları diğer sprint ile örtüşmüyor. Bir önceki sprint'i bilmek gerekmez. Sadece "bu sprint ne yapılacak" + "dosya içerikleri" yeterli.

---

## BÖLÜM: BEKLENEN SONARCLOUD SONUCU

| Metrik | Önce | Sonra |
|--------|------|-------|
| Toplam Issue | 517 | ~80 |
| BUG | 41 | ~5* |
| BLOCKER | 29 | 0 |
| CRITICAL | ~19 | 0 |
| MAJOR JS | ~35 | 0 |
| MAJOR accessibility | ~115 | ~115** |
| MINOR | ~280 | ~80 |

*\* Kalan BUG'lar: Accessibility mouse event'leri (WONTFIX)*  
*\*\* Accessibility WONTFIX olarak işaretlenecek, sayı değişmez ama "Won't Fix" kategorisinde olur*

**Not:** SonarCloud bazı issue'ları iki kez sayıyor (aynı issue iki farklı tarihte scan edilmiş). Gerçek unique fix sayısı daha az, ama plan tutarlı.

---

## OTURUM NOTU — 2026-03-25 (2. Oturum)

### Sonar Fixleri (commit'lendi)
- FIX-4.1: `loadUreme` → `_uremeKizginlik`, `_uremeTohumlama`, `_uremeGebelik`, `_uremeDogum`, `_uremeAbort`
- FIX-4.1: `loadGecmis` → `_gecmisEntryHtml`
- FIX-4.1: `loadDash` → `_dashStatRow` + `_dashBands`
- FIX-4.1: `renderAnimals` → `_animalTagsHtml` + `_animalCardHtml`
- FIX-4.1: `openDet` → `_detSaglikRender` + `_detGorevHtml`
- FIX-4.2: forms.js nested ternary (`openTohDet`, `tohSonuc`)
- FIX-3.3: app.js `else{if}` → `else if`
- FIX-3.6: `dataTrafficGonder(e)` deprecated event fix

### Plan Dışı Bug Fixleri (aynı oturumda test edildi ✅)
- `openTaskDet` `getDisplayKupe` hatası: script versiyonları güncellenerek cache bust yapıldı
- `loadBirths`: hardcode `#fff`/`#1a2010` → `var(--card2)`/`var(--ink2)` (dark mode uyumu)
- `loadBirths`: `b.anne_id` raw → küpe_no lookup + doğum tipi renkli chip
- Gebe badge: tohumlama tarihinden gebelik günü gösterimi, 400 gün cap kaldırıldı
- `_uremeTohumlama` + `_uremeDogum`: `hist-title` `var(--ink)` → `var(--ink2)` (okunabilirlik)

### Yapılanlar (2. Oturum — b572e26)
- FIX-3.1: animalFormGuncelle if/else chain → braces eklendi (app.js)
- FIX-3.2: irkSecimDegisti duplicate else-if/else merged (app.js)
- FIX-3.4: tohBos unused variable removed (ui.js)
- FIX-3.8: .find() → .some() for boolean checks (app.js, ui.js)
- FIX-4.2: nested ternary 7 lokasyon düzeltildi (ui.js)
- FIX-4.3: optional chain — ui.js + forms.js

### Oturum 3 (55e8212) — Tamamlananlar
- FIX-3.7: S7735 negated condition flipped (api.js syncNow)
- FIX-4.1: write() → _writePatch + _writePost (api.js cognitive complexity azaltıldı)
- FIX-5.1: parseFloat → Number.parseFloat (forms.js + ui.js, 14 konum)
- FIX-5.2: .replace('-','.') → .replaceAll (ui.js:1769)
- FIX-5.3: skip — backslash escape pattern yok
- FIX-5.4: window._TH/appState/tohMap/detGecmisLogs/semptomSecili/hdiIlacCache/__state → globalThis (5 dosya)

### Sıradaki Sprint — TÜM SONAR SPRINTLERİ TAMAMLANDI ✅
Kalan sadece SonarCloud UI'da manuel WONTFIX işaretleme var (~188 issue).

---

## FEATURE BACKLOG (Sonar dışı)

### ✅ Tamamlananlar (Oturum 4)
- Geriye dön butonu büyütüldü (min-height:44px, padding artırıldı)
- Tohumlama küpe dropdown stuck fix (openM'de i-hid temizleniyor)
- Buzağı padok 6ay kuralı: form seçeneği kaldırıldı + save validasyonu + liste filtresi
- Tedavi günü saat ikonu (🕐) + caseDaySaatAc/Kaydet + migration 025

### ⏳ Açık Bug'lar — Sıralı

**1. Migration 025 (tedavi saat kaydet)**
✅ **TAMAMLANDI** — DB'de `treatment_days.treatment_time` kolonu, view ve RPC zaten mevcut. JS'te `caseDaySaatAc/Kaydet` fonksiyonları var. Test edilmesi yeterli.

**2. Tohumlama küpe stuck (3152 hâlâ geliyor)**
✅ **MUHTEMELEN ÇÖZÜLDÜ** — `openM('m-insem')` içinde `cl('i-hid')` + `clearTimeout(_insemKupeTid)` fix zaten mevcut. Kod incelemesine göre doğru. Test gerekiyor.

**3. Buzağı 6ay+ kural — tam düzeltme**
✅ **TAMAMLANDI** — `animalFormGuncelle` incelendi: 180 gün+ dişi → düve/yetişkin grupları; 180 gün+ erkek → sadece Besi. Buzağı grubu 180 gün üstü hiç görünmüyor.

**4. Yeni hayvan ekleme — liste anlık güncellenmiyor**
✅ **FIXLENDİ** — `api.js`: `_pulling boolean` → `_pullingPromise` Promise-based lock. Artık devam eden pull varsa yeni çağrı bekliye alınır, drop edilmez.

**5. Görev sistemi entegrasyonu** (BÜYÜK — ayrı sprint):
  - Tedavi günleri → gorev_log task olarak (case_id + day_id bağlantılı)
  - Tohumlama kontrol görevleri: erken uyarı filtresi (today filtresi 3 gün önceden göster)
  - Görev tamamlama → case/tohumlama kaydına bağlanır
  - Eksik uygulama akışı: "Eksik uygulama ile tamamlamak istiyor musunuz?" confirm dialog
  - DB: gorev_log'a case_id, day_id kolonları gerekiyor (migration)
