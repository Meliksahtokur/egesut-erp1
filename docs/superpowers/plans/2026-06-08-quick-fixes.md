# Big Analysis Quick Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kod review (2026-06-08) bulgularındaki 7 quick win'i uygula — Türkçe sıralama, XSS koruması, async/await, const/let, ternary dead code, fonksiyon imzası, tooling token temizliği.

**Architecture:** Her fix bağımsız, tek satır ya da birkaç satır değişiklik. Ortak bağımlılık yok — sırayla yapılabilir. Test framework yok (0% coverage); doğrulama adımları manuel browser/console kontrolüdür.

**Tech Stack:** Vanilla JS (ui.js, forms.js, app.js, api.js), bash scripts (.claude/scripts/)

---

## Kapsam Dışı (Bu Plan)

- `pullTables` partial fail → ayrı plan: `2026-06-08-offline-guvenilirlik.md`
- RLS audit (OV3) → single-tenant için kabul edildi
- Monolith bölme (LV1/LV2) → ön koşullar tamamlanmadan başlanmaz

---

## Dosya Haritası

- Modify: `js/forms.js` — Task 1 (const→let, kaydetTaskEdit imzası, sort x3)
- Modify: `js/ui.js` — Task 2 (sort x4), Task 3 (XSS esc() x3 lokasyon), Task 4 (await x2)
- Modify: `js/app.js` — Task 5 (ternary dead code)
- Modify: `.claude/scripts/supa-query.js` — Task 6 (hardcoded token)
- Modify: `.claude/scripts/supa-query.sh` — Task 6 (hardcoded token)

---

## Task 1: forms.js — const/let, kaydetTaskEdit imzası, sort localeCompare

**Files:**
- Modify: `js/forms.js:1616` (const → let)
- Modify: `js/forms.js:917` (kaydetTaskEdit çağrısında fazla argümanları kaldır)
- Modify: `js/forms.js:436` (sort → localeCompare)
- Modify: `js/forms.js:1397` (sort → localeCompare)
- Modify: `js/forms.js:1510` (sort → localeCompare)

- [ ] **Step 1: const → let düzelt (forms.js:1616)**

`forms.js:1616` satırını bul (function içinde `const idKey = prefix === 'bv'...` olan satır):

```js
// ÖNCE (satır ~1616):
const idKey = prefix === 'bv' ? '_bvAnimalIds' : '_biAnimalIds';

// SONRA:
let idKey = prefix === 'bv' ? '_bvAnimalIds' : '_biAnimalIds';
```

- [ ] **Step 2: kaydetTaskEdit çağrısını düzelt (forms.js:917)**

`forms.js`'te şunu bul:
```js
openConfirm('✏️ Görevi Düzenle', diffSatirlari.join('\n'), async() => kaydetTaskEdit(btn, t, degisen, desc, tarih, tip));
```

Şuna değiştir (fazla 3 argümanı kaldır — fonksiyon sadece 3 alıyor, diğerleri zaten `degisen` içinde):
```js
openConfirm('✏️ Görevi Düzenle', diffSatirlari.join('\n'), async() => kaydetTaskEdit(btn, t, degisen));
```

- [ ] **Step 3: forms.js:436 — hastalık kategorisi sort localeCompare**

Şunu bul:
```js
Object.keys(grouped).sort().forEach(cat => {
```

Şuna değiştir:
```js
Object.keys(grouped).sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'})).forEach(cat => {
```

- [ ] **Step 4: forms.js:1397 — padok adları sort localeCompare**

Şunu bul (iki adet var, ilki ~1397):
```js
const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort();
```

Şuna değiştir:
```js
const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'}));
```

- [ ] **Step 5: forms.js:1510 — padok adları sort localeCompare (ikinci lokasyon)**

Aynı satırı ~1510'da da bul ve Step 4 ile aynı değişikliği yap:
```js
// ÖNCE:
const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort();

// SONRA:
const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'}));
```

- [ ] **Step 6: Doğrula**

Browser console'da:
```js
// Hastalık seçici açıkken (Vaka Aç modalı):
// "İ" ile başlayan kategoriler "i" ile başlayanlardan ÖNCE gelmeli (Türkçe alfabetik)
// Örn: "İç Hastalıklar" > "Ayak" sıralamasında İ doğru yerde olmalı

// Padok seçicide: "Üretim Padok" gibi Ü ile başlayanlar Z'den önce gelmeli
```

- [ ] **Step 7: Commit**

```bash
git add js/forms.js
git commit -m "fix: forms.js — const→let, kaydetTaskEdit 3 arg, sort localeCompare (3 lokasyon)"
```

---

## Task 2: ui.js — sort localeCompare (4 lokasyon)

**Files:**
- Modify: `js/ui.js:2820` (ilaç grup adları sort)
- Modify: `js/ui.js:2838` (ilaç sınıf adları sort)
- Modify: `js/ui.js:2564` (etken madde grubu sort)
- Modify: `js/ui.js:4582` (stok grup adları sort)

- [ ] **Step 1: ui.js:2820 — ilaç grup adları**

Şunu bul (tanımlar paneli, drug class tree render):
```js
const gruplar=Object.keys(tree).sort();
```

Şuna değiştir:
```js
const gruplar=Object.keys(tree).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'}));
```

- [ ] **Step 2: ui.js:2838 — ilaç alt grup (sınıf) adları**

Şunu bul (hemen altında):
```js
Object.keys(altGruplar).sort().forEach(cls=>{
```

Şuna değiştir:
```js
Object.keys(altGruplar).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).forEach(cls=>{
```

- [ ] **Step 3: ui.js:2564 — etken madde dropdown grubu**

Şunu bul (yeni ilaç ekleme modalı):
```js
Object.entries(grouped).sort().map(([grp, list]) =>
```

Şuna değiştir:
```js
Object.entries(grouped).sort(([a],[b])=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(([grp, list]) =>
```

- [ ] **Step 4: ui.js:4582 — stok grubu**

Şunu bul (stok listesi paneli):
```js
const groupHtml = Object.keys(groups).sort().map(grp => {
```

Şuna değiştir:
```js
const groupHtml = Object.keys(groups).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(grp => {
```

- [ ] **Step 5: Doğrula**

Browser'da tanımlar panelini aç → İlaç sınıfları listesinde "Antimikrobiyaller" "Anti-inflamatuar"dan önce gelmiyor mu? Türkçe sıralaması kontrol et.

- [ ] **Step 6: Commit**

```bash
git add js/ui.js
git commit -m "fix: ui.js — sort localeCompare ekle (4 lokasyon, ilaç grubu/sınıfı/etken/stok)"
```

---

## Task 3: ui.js — onclick XSS esc() (3 lokasyon)

**Files:**
- Modify: `js/ui.js:1390-1391` (kupe_no in openMWithHayvan)
- Modify: `js/ui.js` ~5969 (p.ad in setPadokFiltreBt)
- Modify: `js/ui.js` ~6457 (kupe_no in padokTekliTasi)

`esc()` helper zaten tanımlı — DOM textContent tabanlı, doğru implementasyon.

- [ ] **Step 1: ui.js:1390-1391 — hayvan detay paneli, Vaka Aç / Aşı Uygula butonları**

Şunu bul (hayvan detay panelindeki iki buton, `openMWithHayvan` çağrıları):
```js
<button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-disease','d-hid','${a.kupe_no||a.devlet_kupe||a.id}')">🏥 Vaka Aç</button>
<button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-vaccine','v-hid','${a.kupe_no||a.devlet_kupe||a.id}')">💉 Aşı Uygula</button>
```

Şuna değiştir:
```js
<button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-disease','d-hid','${esc(a.kupe_no||a.devlet_kupe||a.id)}')">🏥 Vaka Aç</button>
<button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-vaccine','v-hid','${esc(a.kupe_no||a.devlet_kupe||a.id)}')">💉 Aşı Uygula</button>
```

- [ ] **Step 2: ui.js ~5969 — padok doluluk chip'i setPadokFiltreBt**

Şunu bul (`setPadokFiltreBt` çağrısı olan iki `div` — p.ad hem onclick'te hem title'da):
```js
return `<div class="pdoluluk-chip" onclick="setPadokFiltreBt('${p.id}','${p.ad}')" title="${p.ad}: ${dolu} hayvan">
```
ve
```js
return `<div class="pdoluluk-chip" onclick="setPadokFiltreBt('${p.id}','${p.ad}')" title="${p.ad}: ${dolu}/${kap}">
```

Her ikisinde de onclick içindeki `p.ad`'ı esc ile sar. `title` güvenli (innerHTML değil), onclick unsafe:
```js
return `<div class="pdoluluk-chip" onclick="setPadokFiltreBt('${p.id}','${esc(p.ad)}')" title="${p.ad}: ${dolu} hayvan">
```
```js
return `<div class="pdoluluk-chip" onclick="setPadokFiltreBt('${p.id}','${esc(p.ad)}')" title="${p.ad}: ${dolu}/${kap}">
```

- [ ] **Step 3: ui.js ~6457 — padok tek hayvan taşı butonu**

Şunu bul (`padokTekliTasi` çağrısı):
```js
<button class="btn" style="padding:3px 8px;font-size:.7rem;background:rgba(42,107,181,.1);color:var(--blue);border:1px solid rgba(42,107,181,.2)" onclick="padokTekliTasi('${h.id}','${h.kupe_no || h.devlet_kupe || h.id}')">➡️</button>
```

Şuna değiştir:
```js
<button class="btn" style="padding:3px 8px;font-size:.7rem;background:rgba(42,107,181,.1);color:var(--blue);border:1px solid rgba(42,107,181,.2)" onclick="padokTekliTasi('${h.id}','${esc(h.kupe_no || h.devlet_kupe || h.id)}')">➡️</button>
```

- [ ] **Step 4: Doğrula**

Browser console'da:
```js
// esc() fonksiyonu düzgün çalışıyor mu?
esc("test'injection")
// Beklenen: "test&#x27;injection" ya da entity-escaped form
// Tek tırnak escape edilmişse onclick string kırılmaz
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "fix: ui.js — onclick XSS esc() eklendi (kupe_no, p.ad, padokTekliTasi)"
```

---

## Task 4: ui.js — idbGetAll await eksik (2 lokasyon)

**Files:**
- Modify: `js/ui.js:853-855` (`_etkenFiltrele` fonksiyonu — sync fonksiyon içinde async call)

**Bağlam:** `_etkenFiltrele` sync fonksiyon. `idbGetAll()` async döner — `.forEach()` Promise üzerinde çağrılıyor, map'ler her zaman boş kalıyor. Bu `dcMap`/`dpMap` lookup'larını tamamen devre dışı bırakıyor. Düzeltme: fonksiyonu `async` yap ve `await` ekle. Caller'ları kontrol etmek gerekiyor.

- [ ] **Step 1: _etkenFiltrele caller'larını kontrol et**

```bash
grep -n "_etkenFiltrele" js/ui.js
```

Çıktı beklentisi: Her caller `await _etkenFiltrele(...)` veya caller'lar async fonksiyon içinde olmalı. Eğer caller'lar sync ise onları da async yapmak gerekir.

- [ ] **Step 2: _etkenFiltrele'yi async yap + await ekle**

Şunu bul (ui.js ~848):
```js
function _etkenFiltrele(etkenKod, stoklar) {
  const rx = _ETKEN_INGREDIENT[etkenKod];
  if (!rx) return [];
  const dcMap = {};  // drug_class_id → active_ingredient
  try { idbGetAll('drug_classes').forEach(dc => { dcMap[dc.id] = dc.active_ingredient||''; }); } catch(e) {}
  const dpMap = {};  // drug_product_id → drug_class_id
  try { idbGetAll('drug_products').forEach(dp => { dpMap[dp.id] = dp.drug_class_id; }); } catch(e) {}
```

Şuna değiştir:
```js
async function _etkenFiltrele(etkenKod, stoklar) {
  const rx = _ETKEN_INGREDIENT[etkenKod];
  if (!rx) return [];
  const dcMap = {};  // drug_class_id → active_ingredient
  try { (await idbGetAll('drug_classes')).forEach(dc => { dcMap[dc.id] = dc.active_ingredient||''; }); } catch(e) {}
  const dpMap = {};  // drug_product_id → drug_class_id
  try { (await idbGetAll('drug_products')).forEach(dp => { dpMap[dp.id] = dp.drug_class_id; }); } catch(e) {}
```

- [ ] **Step 3: Caller'lara await ekle**

Step 1'deki grep çıktısındaki her caller satırında `await` ekle. Örnek:
```js
// ÖNCE:
const filtered = _etkenFiltrele(etkenKod, stoklar);

// SONRA:
const filtered = await _etkenFiltrele(etkenKod, stoklar);
```

Caller'ın parent fonksiyonu `async` değilse başına `async` ekle.

- [ ] **Step 4: Doğrula**

Browser'da protokol uygulama alanında etken madde filtresi çalışan bir ekrana git (klinik akış varsa). Console'da `_etkenFiltrele` çağrısının boş sonuç yerine gerçek stok filtresi dönmesi gerekiyor.

Alternatif console testi:
```js
// Devtools Console:
_etkenFiltrele('PENISILIN', await idbGetAll('stok')).then(r => console.log('Sonuç:', r.length))
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "fix: ui.js — _etkenFiltrele async yap, idbGetAll await eksik düzeltildi"
```

---

## Task 5: app.js — ternary dead code (semptomEkle)

**Files:**
- Modify: `js/app.js:~494`

**Bağlam:** `const val = sel.value || sel._noReset && sel.value === '' ? sel.value : sel.value;` — operatör önceliği nedeniyle her zaman `sel.value` döner. `_noReset` flag'inin `val` hesaplamasında etkisi yok. Güvenli fix: dead ternary'yi kaldır, eşdeğer sadeleştirilmiş kod yaz.

- [ ] **Step 1: Ternary'yi sadeleştir**

Şunu bul:
```js
function semptomEkle(sel) {
  const val = sel.value || sel._noReset && sel.value === '' ? sel.value : sel.value; if (!val) return;
```

Şuna değiştir:
```js
function semptomEkle(sel) {
  const val = sel.value; if (!val) return;
```

**Not:** Bu mevcut davranışla işlevsel olarak aynıdır (ternary zaten her zaman `sel.value` döndürüyordu). `_noReset` flag'inin `sel.value = ''` sıfırlama kısmındaki etkisi korunuyor.

- [ ] **Step 2: Doğrula**

Browser'da semptom ekleme modalını aç (klinik form varsa) → semptom seçici dropdown'ından bir değer seç → chip eklendiğini doğrula → seçici sıfırlanıyor mu?

- [ ] **Step 3: Commit**

```bash
git add js/app.js
git commit -m "fix: app.js — semptomEkle ternary dead code kaldırıldı"
```

---

## Task 6: Developer Tooling — Hardcoded Token Temizliği

**Files:**
- Modify: `.claude/scripts/supa-query.js:10`
- Modify: `.claude/scripts/supa-query.sh:8`

**Bağlam:** `sbp_235a8cfe...` bir Supabase personal access token (privileged). GitHub'a push edilmişse already exposed — ama git history'de kalmaya devam etmemeli. Fix: hardcoded fallback kaldır, sadece env var kullan.

- [ ] **Step 1: supa-query.js token fallback kaldır**

Şunu bul:
```js
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'sbp_235a8cfe38b40eb8c5f9bde9e31301d97cbc89c9';
```

Şuna değiştir:
```js
const SUPABASE_KEY = process.env.SUPABASE_KEY;
if (!SUPABASE_KEY) { console.error('SUPABASE_KEY env var gerekli'); process.exit(1); }
```

- [ ] **Step 2: supa-query.sh token değişkeni env'dan al**

Şunu bul:
```bash
SUPABASE_ACCESS_TOKEN="sbp_235a8cfe38b40eb8c5f9bde9e31301d97cbc89c9"
```

Şuna değiştir:
```bash
SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-${SUPABASE_KEY}}"
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then echo "SUPABASE_ACCESS_TOKEN veya SUPABASE_KEY env var gerekli" >&2; exit 1; fi
```

- [ ] **Step 3: Kullanım notunu güncelle (script header)**

`supa-query.js` header'ında kullanım açıklamasına env var gereksinimini ekle:
```js
// Kullanım: SUPABASE_KEY=sbp_xxx node supa-query.js "SELECT * FROM hayvanlar LIMIT 5"
```

`supa-query.sh` header'ında:
```bash
# Kullanım: SUPABASE_ACCESS_TOKEN=sbp_xxx ./supa-query.sh "SELECT ..."
# veya:     SUPABASE_KEY=sbp_xxx ./supa-query.sh "SELECT ..."
```

- [ ] **Step 4: Doğrula**

```bash
# Token olmadan çalıştır — hata vermeli:
node .claude/scripts/supa-query.js "SELECT 1"
# Beklenen: "SUPABASE_KEY env var gerekli" ve exit 1

# Token ile çalıştır — çalışmalı:
SUPABASE_KEY=sbp_... node .claude/scripts/supa-query.js "SELECT 1"
```

- [ ] **Step 5: Commit**

```bash
git add .claude/scripts/supa-query.js .claude/scripts/supa-query.sh
git commit -m "fix: tooling — hardcoded Supabase token kaldırıldı, env var zorunlu"
```

---

## Tamamlama

Tüm task'lar bitince:

- [ ] **Final push**
```bash
git push origin fix/big-analysis-2026-06-08
```

- [ ] **Özet kontrol**
```bash
git log --oneline fix/big-analysis-2026-06-08 ^main
```

Beklenen 6 commit: forms.js, ui.js sort, ui.js XSS, ui.js await, app.js, tooling.
