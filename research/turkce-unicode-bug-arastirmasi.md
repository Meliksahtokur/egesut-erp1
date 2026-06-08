# Türkçe Unicode Bug Araştırması — EgeSüt ERP

**Tarih:** 2026-06-01  
**Kapsam:** js/*.js, js/utils/*.js  
**Yöntem:** grep_files + ast_grep_search + semantic_search + 2 parallel explorer agent

---

## Bug Tanımı

JavaScript'te `"İ".toLowerCase()` → `"i\u0307"` (i + combining dot above) döner, `"i"` DEĞİL.

```
"İnek".toLowerCase()          → "i\u0307nek"
"i\u0307nek".includes("inek") → FALSE! ✗
"İnek".toLowerCase() === "inek" → FALSE! ✗
```

**Etkilenen karakterler:**
| Karakter | toLowerCase | toUpperCase |
|----------|-------------|-------------|
| `İ` (U+0130) | `i\u0307` (i + combining dot) | `İ` (korur) |
| `I` (U+0049) | `i` (standart) veya `ı` (Türkçe locale) | `I` (korur) |
| `ı` (U+0131) | `ı` (korur) | `I` (ASCII I) **veya** `İ` (bağlama göre) |
| `i` (U+0069) | `i` (korur) | `i` (korur) veya `İ` (Türkçe locale) |

**Pratikte en tehlikeli kombinasyon:** DB'den gelen veride `İ` varsa (örn. "Gebe İnek", "Süt İçen Buzağı", "İlaç", "Diğer İlaç") ve bu veri `.toLowerCase()` yapılıp `.includes()` ile aranırsa, kullanıcının girdiği ASCII `i` ile eşleşmez.

---

## BULGULAR

---

### 🔴 YÜKSEK RİSK — 5 bulgu

#### H1. js/utils/helpers.js:48 — setupAutocomplete (generic)
```js
else { const lq = q.toLowerCase(); list = opts.source.filter(s => s.toLowerCase().includes(lq)); }
```
- **Risk:** Bu autocomplete generic — herhangi bir kaynakla kullanılabilir. Eğer `opts.source` içindeki string'lerde Türkçe `İ` varsa (örn. ilaç adları, grup adları) ve kullanıcı ASCII `i` ile ararsa, `s.toLowerCase()` combining dot üretir ve `.includes(lq)` başarısız olur.
- **Gerçek hayat senaryosu:** "İlaç" yazılı bir kaynakta "ilac" aranır → `"i\u0307laç".includes("ilac")` → false.

#### H2. js/ui.js:4655 — acIlac (ilaç autocomplete)
```js
const filtered=q?_ilacCache.filter(s=>s.urun_adi.toLowerCase().includes(q)):_ilacCache.slice(0,12);
```
- **Risk:** `_ilacCache` stok ürünlerini içerir — `urun_adi` değerleri "İlaç", "Diğer İlaç" gibi Türkçe `İ` içeren isimler olabilir. Kullanıcı "ilac" yazarsa hiçbir sonuç bulamaz.
- **Etkilenen akış:** Tedavi formunda ilaç arama.

#### H3. js/ui.js:4698-4699 — acDilacSatir (ilac satırı autocomplete)
```js
const stoklar=getState('stock').filter(s=>s.kategori!=='Sperma'&&!(s.urun_adi||'').toLowerCase().includes('sperma'));
const filtered=q?stoklar.filter(s=>(s.urun_adi||'').toLowerCase().includes(q)):stoklar.slice(0,8);
```
- **Risk:** Aynı `urun_adi.toLowerCase().includes(q)` problemi. Kullanıcı ilaç adında "i" içeren bir terim ararsa (örn. "ilac") ve stokta "İlac..." varsa bulamaz.
- **Not:** "sperma" kontrolü ASCII olduğu için güvenli, ama `.includes('sperma')` genel olarak `'sperma'` string'inin kendisi ASCII olduğu için sorun yok.

#### H4. js/ui.js:5690-5691 — stokFiltrele
```js
const ad = (row.dataset.ad || '').toLowerCase();
if (!q || ad.includes(q)) { row.style.display = ''; visible++; }
```
- **Risk:** `data-ad` stok ürün adını içerir. Ürün adında "İ" varsa ve kullanıcı "i" ile ararsa eşleşmez.
- **Etkilenen akış:** Stok panelinde ürün arama. "İlaç" yazılı ürünü "ilac" yazarak bulamama.

#### H5. js/ui.js:4698 (üst satır) — Sperma filtreleme
```js
!(s.urun_adi||'').toLowerCase().includes('sperma')
```
- **Risk:** Düşük aslında çünkü "sperma" kelimesi ASCII. Ama eğer ürün adı "Sperma İçin X" gibi bir şeyse ve sonradan `.includes('sperma')` kontrolü yapılıyorsa, "Sperma" kısmı ASCII olduğu için sorun yok.
- **Not:** Bu specifik örnek güvenli. Ama aynı pattern'de `urun_adi` içinde `İ` olup da başka bir ASCII string aranıyorsa, eğer `İ` karakteri aranan string'den önce geliyorsa `.includes()` yine de çalışır (çünkü combining dot sadece ondan sonraki karakterleri etkilemez).

---

### 🟠 ORTA RİSK — 6 bulgu

#### M1. js/ui.js:819 — srchDropdown (hayvan arama dropdown)
```js
return k.includes(q)||d.includes(q)||(a.irk||'').toLowerCase().includes(q);
```
- **Risk:** `irk` alanı "Simental", "Holştayn", "Kırım" gibi değerler alabilir. "Kırım"da `ı` var ama `İ` yok. "Simental" ASCII. Eğer irk değerleri arasında "İsviçre Esmeri" gibi bir değer varsa risk oluşur.
- **Gerçek risk:** Düşük-orta, çünkü ırk isimleri genelde ASCII veya `ı/ü/ğ/ş/ç/ö` içerir, `İ` nadir.

#### M2. js/ui.js:864 — filterA (hayvan listesi filtre)
```js
if(q) f=f.filter(a=>(a.id+(a.kupe_no||'')+(a.devlet_kupe||'')+(a.irk||'')).toLowerCase().includes(q));
```
- **Risk:** Aynı `irk` içinde `İ` varsa. `a.id` (UUID), `kupe_no`, `devlet_kupe` genelde ASCII.

#### M3. js/ui.js:5479-5481 — padokHayvanFiltre
```js
(h.kupe_no || '').toLowerCase().includes(filtre) ||
(h.devlet_kupe || '').toLowerCase().includes(filtre) ||
(h.irk || '').toLowerCase().includes(filtre)
```
- **Risk:** `irk` içinde `İ`. Aynı M1/M2 problemi.

#### M4. js/forms.js:1634 — filterBulkSerbest (toplu aşılama/ilaçlama filtre)
```js
l.style.display = l.textContent.toLowerCase().includes(q) ? '' : 'none';
```
- **Risk:** Label text içinde "Süt İçen Buzağı", "Gebe İnek" gibi `İ` içeren grup adları olabilir. Kullanıcı "ine" yazarak "Gebe İnek"i bulamaz.

#### M5. js/forms.js:392 — disease filter (kızgınlık tedavi akışı)
```js
? list.filter(d => (d.category || '').toLowerCase() === 'üreme')
```
- **Risk:** `Ü` → `ü` dönüşümü JavaScript'te sorunsuz çalışır (ü lowercased → ü, combining mark yok). DÜŞÜK risk.
- **Ama:** `d.category` DB'den gelir. Kategori değeri `'Üreme'` ise `'üreme'` ile karşılaştırma başarılı olur.

#### M6. js/forms.js:1165 — stok ekleme duplicate check
```js
const mevcut = mevcutlar.find(s => s.urun_adi?.toLowerCase() === urun.toLowerCase() && s.kategori === kat);
```
- **Risk:** `urun` kullanıcının girdiği metin. Eğer "İlaç" yazarsa, `urun.toLowerCase()` → `"i\u0307laç"`. DB'deki `urun_adi` de "İlaç" ise `s.urun_adi?.toLowerCase()` → `"i\u0307laç"`. Her iki taraf da aynı combining dot'u ürettiği için karşılaştırma **çalışır**. Ama kullanıcı "ilac" (ASCII) yazarsa ve DB'de "İlaç" varsa, `"ilac" !== "i\u0307laç"` → false. Bu da stok güncelleme yerine yeni kayıt oluşturur — veri duplikasyonu riski.

---

### 🟢 DÜŞÜK RİSK — 8 bulgu

#### L1. js/api.js:32 — _trErr error mapping
```js
const found = _ERR_MAP.find(([k]) => m.toLowerCase().includes(k.toLowerCase()));
```
- `_ERR_MAP` key'leri İngilizce (`'row-level security'`, `'duplicate key'`). `m` Supabase hata mesajı (İngilizce). Türkçe `İ` yok.

#### L2. js/app.js:373-374 — spermaModStok filtre
```js
(s.urun_adi || '').toLowerCase().includes('sperma')
(s.urun_adi || '').toLowerCase().includes('doz')
```
- Aranan string'ler ASCII (`'sperma'`, `'doz'`). Sperma adlarında `İ` bulunma ihtimali düşük.

#### L3. js/ui.js:812-819 — srchDropdown (kupe_no arama)
```js
const k=(a.kupe_no||'').toLowerCase(), d=(a.devlet_kupe||'').toLowerCase();
return k.includes(q)||d.includes(q)...
```
- Küpe numaraları alfanumerik (TR12345 gibi), `İ` içermez.

#### L4. js/ui.js:4765 — acHayvan (küpe arama)
```js
src.filter(a=>(a.kupe_no||'').toLowerCase().includes(q)||(a.devlet_kupe||'').toLowerCase().includes(q)||(a.id||'').toLowerCase().includes(q))
```
- `kupe_no`, `devlet_kupe`, `id` — hepsi ASCII/alfanumerik.

#### L5. js/ui.js:5706-5712 — taskSrch (görev küpe arama)
```js
const text = (idSpan?.textContent||'').toLowerCase();
if (!q || text.includes(q)) { card.style.display = ''; visible++; }
```
- Görev küpe numaraları alfanumerik.

#### L6. js/ui.js:1503 — kızgınlık arama
```js
k.hayvan_id.toLowerCase().includes(q)
```
- `hayvan_id` UUID formatında (ASCII).

#### L7. js/forms.js:181 — _ekStokYukle (kategori filtre)
```js
kategoriler.some(k => (s.kategori||'').toLowerCase().includes(k.toLowerCase()))
```
- `k` değerleri: 'Diğer İlaç', 'Diger Ilac', 'Hormon', 'Vitamin'
- `k.toLowerCase()`:
  - `'Diğer İlaç'.toLowerCase()` → `'diğer i\u0307laç'`
  - `'Diger Ilac'.toLowerCase()` → `'diger ilac'`
- `s.kategori` DB'den gelir. Eğer DB'de `'Diğer İlaç'` ise, her iki taraf da `.toLowerCase()` yapıldığı için aynı combining dot'u üretir ve eşleşme çalışır.
- Ama DB'de `'Diger Ilac'` (ASCII) varsa ve `k='Diğer İlaç'` ise, `'diger ilac'` vs `'diğer i\u0307laç'` karşılaştırması eşleşmez!
- **Portföy riski:** Düşük, çünkü DB'deki kategori değerleri muhtemelen tutarlı.

#### L8. js/ui.js:626 — toUpperCase
```js
const init=mainId.replace(/\D/g,'').slice(-3)||mainId.slice(0,2).toUpperCase()
```
- `mainId` kupe_no veya devlet_kupe. `toUpperCase()` sadece ID'nin ilk 2 karakterini büyütür. ID'ler alfanumerik olduğu için Türkçe karakter riski yok.

---

## GÜVENLİ DESENLER (false positive değil)

Aşağıdaki desenlerde `.toLowerCase()` olmadan direkt `===` karşılaştırması yapılıyor. Bunlar **güvenli** çünkü Türkçe `İ` içeren string'ler olduğu gibi karşılaştırılıyor, lowercasing yapılmıyor:

### js/ui.js:4740 — _eligibleHayvanlar
```js
if(['Sağmal (Laktasyonda)','Sağmal (Kuru)','Gebe İnek','Gebe Düve','Düve (Büyük)'].includes(a.grup)) return true;
```
- ✅ Güvenli — direkt `.includes()` ile dizi içinde arama, `.toLowerCase()` yok.

### js/ui.js:883 — filterA boş hayvan kontrolü
```js
return ['Sağmal (Laktasyonda)','Sağmal (Kuru)','Gebe İnek','Gebe Düve','Düve (Büyük)'].includes(a.grup);
```
- ✅ Güvenli — aynı desen.

### js/forms.js:41-46 — submitAnimal grup validasyonu
```js
if (_grup === 'Süt İçen Buzağı' && _yasGun > 180) { ... }
```
- ✅ Güvenli — direkt `===`.

### js/app.js:292-306 — getSuggestedGroups (grup önerme)
```js
gruplar = ['Sağmal (Laktasyonda)', 'Sağmal (Kuru)'];
gruplar = ['Gebe Düve', 'Sağmal (Laktasyonda)', 'Sağmal (Kuru)', 'Düve (Büyük)', 'Düve (Küçük)'];
```
- ✅ Güvenli — direkt `'Gebe İnek'` gibi string'ler <option> olarak render edilir, `.toLowerCase()` yok.

### js/app.js:371-372 — sperma stok filtre
```js
s.kategori === 'Sperma' || s.grup === 'Sperma'
```
- ✅ Güvenli — direkt `===` ile İngilizce string karşılaştırması.

---

## SEMANTIC SEARCH EK BULGULARI

Araştırma sırasında `semantic_search`, `ast_grep_search` ve `knowledge_graph_query` ile ek pattern'ler tarandı. `.toLocaleLowerCase('tr')` kullanımı bulunamadı — projede Türkçe locale-aware string karşılaştırma hiç yok.

`ILIKE` kullanımı JS tarafında bulunamadı — tüm DB sorguları RPC üzerinden yapılıyor, SQL string birleştirme yapılmıyor.

---

## RAPOR ÖZETİ

| Seviye | Sayı | Dosyalar |
|--------|------|----------|
| 🔴 YÜKSEK | 5 | helpers.js:48, ui.js:4655, ui.js:4698-4699, ui.js:5690-5691 |
| 🟠 ORTA | 6 | ui.js:819, ui.js:864, ui.js:5479-5481, forms.js:1634, forms.js:392, forms.js:1165 |
| 🟢 DÜŞÜK | 8 | api.js:32, app.js:373-374, ui.js:812-819, ui.js:4765, ui.js:5706-5712, ui.js:1503, forms.js:181, ui.js:626 |

### En kritik bulgular:

1. **İlaç autocomplete (ui.js:4655, 4699)** — Tedavi formunda ilaç ararken "İ" içeren ürünler bulunamaz, kullanıcı yanlışlıkla stokta yok zannedebilir veya elle girmeye çalışır.

2. **Stok arama (ui.js:5690-5691)** — Stok panelinde ürün ararken aynı sorun.

3. **Generic autocomplete (helpers.js:48)** — En tehlikeli bulgu çünkü her yerde kullanılan bir yardımcı fonksiyon. Eğer herhangi bir source'ta "İ" varsa, otomatik tamamlama sessizce çalışmaz.

### Sorular / Belirsizlikler:

1. **Irk değerleri:** DB'deki ırk isimleri nelerdir? "İsviçre Esmeri" gibi `İ` içeren bir ırk var mı? Varsa M1-M3'teki riskler yüksek seviyeye çıkar.

2. **Stok ürün adları:** Mevcut stok ürün adlarında "İ" var mı? Örn: "İlac", "İğne", "İzotonik" gibi.

3. **Kategori değerleri:** DB'deki `stok.kategori` değerleri nelerdir? "Diğer İlaç", "İlaç" gibi kategoriler var mı?

4. **`toLocaleLowerCase('tr')` kullanımı:** Hiç kullanılmamış. Bilinçli bir tercih mi, yoksa farkında olunmayan bir eksiklik mi?

---

## ÖNERİLEN DÜZELTME STRATEJİSİ

```js
// Mevcut (hatalı):
s.toLowerCase().includes(q)

// Düzeltme 1 — Unicode normalization (en temiz):
s.normalize('NFKD').toLowerCase().includes(q.normalize('NFKD').toLowerCase())
// "i\u0307" → "i" olarak normalize eder

// Düzeltme 2 — replace (hızlı fix):
s.toLowerCase().replace(/[\u0307\u0300-\u036f]/g, '').includes(q.toLowerCase().replace(/[\u0307\u0300-\u036f]/g, ''))

// Düzeltme 3 — localeCompare (ama contains için uygun değil)
```

**Öncelik sırası:**
1. helpers.js:48 — generic autocomplete (en geniş etki)
2. ui.js:4655 — acIlac (tedavi akışı)
3. ui.js:4699 — acDilacSatir (tedavi ilaç satırı)
4. ui.js:5690 — stokFiltrele (stok arama)
5. forms.js:1634 — filterBulkSerbest (toplu işlem)
6. ui.js:819, 864, 5479-5481 — irk araması (ırk verisine bağlı)
