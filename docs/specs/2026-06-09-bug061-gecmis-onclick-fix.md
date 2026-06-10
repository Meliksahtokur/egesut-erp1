# BUG-061 — Hayvan Kartı Geçmiş: gorev/uygulama Tıklama Hayvan Kartını Yeniden Açıyor

## Context

EgeSüt ERP — Vanilla JS single-page app.
Repo: `/root/egesut-erp1`
Main JS: `js/ui.js` (~6000 satır)

## Bug

Hayvan kartı açık, **Geçmiş** sekmesine geçildiğinde:
- `gorev` (TEDAVI_GUN tipi değil) girişlerine tıklanınca hayvan kartı yeniden açılıyor — hiçbir şey olmamalıydı
- `uygulama` girişlerine tıklanınca hayvan kartı yeniden açılıyor — hiçbir şey olmamalıydı

Beklenen davranış:
- `gorev` (TEDAVI_GUN tipi) → `openCaseDet(caseId)` açılmalı ✅ (şu an doğru çalışıyor)
- `gorev` (diğer tipler) → tıklama yapılmamalı (görev detay modal'ı henüz yok)
- `uygulama` → tıklama yapılmamalı (bilgi zaten sağlık sekmesinde)
- `islem` → `openIslemDetay(idx)` açılmalı ✅ (şu an doğru çalışıyor)

## Root Cause (Önceden Teşhis Edildi)

`_gecmisEntryHtml` fonksiyonu iki kontekstten çağrılır:

1. **Global geçmiş sayfası** — `_gecmisRender()` @ ~satır 2538
   - Burada `openDet(hayvan_id)` doğru davranış — farklı hayvanların kayıtları görünüyor
   
2. **Hayvan kartı detay sekmesi** — `_renderDetGecmisList()` @ ~satır 1491
   - Burada `openDet(hayvan_id)` yanlış — zaten o hayvanın kartındasın

`_renderDetGecmisList` `islem` tipi için `overrideOc` override'ı geçiyor ama
`gorev` ve `uygulama` için geçmiyor:

```javascript
// MEVCUT (satır 1491-1494):
if(e.type==='islem') return _gecmisEntryHtml(e,`onclick="openIslemDetay(${e._islemIdx})" style="cursor:pointer"`);
return _gecmisEntryHtml(e);   // ← gorev/uygulama için oc override YOK
```

`_gecmisEntryHtml` içinde (satır 2469 ve 2476) her iki tip için `openDet(hayvan_id)` atanıyor,
override gelmediği için hayvan kartı yeniden açılıyor.

## Fix

**Tek dosya, tek fonksiyon, 2 satır ekleme.**

Dosya: `js/ui.js`
Fonksiyon: `_renderDetGecmisList` (satır ~1491)

```javascript
// ÖNCE:
if(e.type==='islem') return _gecmisEntryHtml(e,`onclick="openIslemDetay(${e._islemIdx})" style="cursor:pointer"`);
return _gecmisEntryHtml(e);

// SONRA:
if(e.type==='islem') return _gecmisEntryHtml(e,`onclick="openIslemDetay(${e._islemIdx})" style="cursor:pointer"`);
if(e.type==='gorev' && e.data?.gorev_tipi!=='TEDAVI_GUN') return _gecmisEntryHtml(e,'');
if(e.type==='uygulama') return _gecmisEntryHtml(e,'');
return _gecmisEntryHtml(e);
```

**Neden bu fix doğru:**
- `overrideOc=''` → `_gecmisEntryHtml` satır 2489'da: `if(overrideOc!==undefined) oc=overrideOc;` → `oc=''` → onclick yok
- Global geçmiş sayfası (`_gecmisRender`) dokunulmadı → `openDet` davranışı orada korunuyor
- `TEDAVI_GUN` gorevi korundu → `openCaseDet` davranışı bozulmadı

## Tools-Bank Araç Kullanımı

Çalışmadan önce şu adımları izle:

### 1. Blast Radius Analizi (ZORUNLU)
```
gitnexus_impact(target="_renderDetGecmisList", direction="upstream")
```
Beklenen: LOW risk (sadece hayvan kartı geçmiş sekmesi çağırıyor).
HIGH/CRITICAL çıkarsa işleme geçmeden raporla.

### 2. Fonksiyon Lokasyonunu Doğrula
```
ast_grep_search(
  pattern="function _renderDetGecmisList($$$) { $$$ }",
  lang="javascript",
  path="js/ui.js",
  max_results=3,
  context_lines=5
)
```
Satır numarasını not al — fix tam bu satıra uygulanacak.

### 3. Mevcut Kodu Kontrol Et
```
semantic_search(query="_renderDetGecmisList gorev uygulama gecmis override")
```
Son commit'te bu fonksiyonun değişip değişmediğini anlamak için.

### 4. Fix Öncesi Exact Context'i Oku
`ast_grep_search` sonucundaki satır numarasıyla ilgili bloğu oku.
Fix'i SADECE `_renderDetGecmisList` içindeki o 2 satıra uygula.

## Uygulama Adımları

1. Blast radius analizi çalıştır (gitnexus_impact)
2. Fonksiyonun mevcut satır numarasını bul (ast_grep_search)
3. İlgili satırları oku (Read tool, offset + limit)
4. Fix'i uygula (Edit tool)
5. Değişikliği doğrula (grep ile)
6. Commit + push

## Commit Formatı

```
fix: BUG-061 gecmis gorev/uygulama onClick hayvan kartını açmasın

_renderDetGecmisList'te gorev(non-TEDAVI_GUN) ve uygulama tipleri
için overrideOc='' eklendi. Global gecmis sayfası etkilenmedi.

Impact: _renderDetGecmisList — LOW
```

## Doğrulama (Grep ile)

```bash
# Fix uygulandı mı?
grep -n "gorev_tipi.*TEDAVI_GUN.*overrideOc\|gecmisEntryHtml.*uygulama.*''" js/ui.js
# → satır görmeli

# Global gecmis bozulmadı mı?
grep -n "_gecmisRender\|gecmisAllEntries" js/ui.js
# → overrideOc geçilmeden çağrılıyor olmalı

# TEDAVI_GUN davranışı korundu mu?
grep -n "TEDAVI_GUN.*caseId\|openCaseDet" js/ui.js
# → openCaseDet hâlâ var olmalı
```

## Sınırlar

- SADECE `js/ui.js` → `_renderDetGecmisList` fonksiyonu içindeki 2 satır
- Başka dosya değiştirme
- `_gecmisEntryHtml`, `_gecmisRender`, `loadGecmis` fonksiyonlarına dokunma
- Migration, SQL, index.html dokunma

---

## ✅ ÇÖZÜLDÜ — 2026-06-10

**Tarihçe düzeltmesi:**

- Spec yazılırken fix uygulanmamış sanılmıştı.
- Gerçek: fix `302d6e1` commit'inde uygulandı, `e875c43`'te "çözüldü" işaretlendi.
- `f159260` reopen değildi — sadece `.claude/knowledge/bugs.md` ve `index.html` dokümantasyon güncellemesiydi (kod değişikliği yok).

**Doğrulama (2026-06-10):**

```bash
sed -n '1486,1496p' js/ui.js
```

```javascript
function _renderDetGecmisList(q){
  ...
  bodyEl.innerHTML=list.map(e=>{
    if(e.type==='islem') return _gecmisEntryHtml(e,`onclick="openIslemDetay(${e._islemIdx})" style="cursor:pointer"`);
    if(e.type==='gorev' && e.data?.gorev_tipi!=='TEDAVI_GUN') return _gecmisEntryHtml(e,'');  // ✅
    if(e.type==='uygulama') return _gecmisEntryHtml(e,'');  // ✅
    return _gecmisEntryHtml(e);
  }).join('');
}
```

- `_gecmisEntryHtml` L2491: `if(overrideOc!==undefined) oc=overrideOc;` — override mantığı doğru çalışıyor.
- `_gecmisRender` L2540: `_gecmisEntryHtml(e)` (parametresiz) → global geçmiş `openDet` davranışı korunuyor.

**Aksiyon:** Spec kapatıldı, kod değişikliği gerekmedi, commit gerekmedi.
