# Kısır / Satılabilir Statüsü Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kısır hayvanları işaretleyip satılabilir statüsüne alabilmek ve filtreleyebilmek.

**Architecture:** `hayvanlar` tablosuna `kisir` (bool) ve `satis_notu` (text) kolonları eklenir. Hayvan kartına toggle eklenir, sürü listesinde filtre desteği verilir. Backend'de `hayvan_kisir_isaretle` RPC'si kısır durumunu set eder ve `islem_log`'a yazar. Kısır hayvanlar otomatik olarak "satılabilir" kabul edilir (ayrı flag gerekmez).

**Tech Stack:** PostgreSQL (Supabase migration), Vanilla JS (ui.js, forms.js, config.js)

---

### Task 1: Database Migration — `kisir` kolonu + RPC

**Files:**
- Create: `supabase/migrations/YYYYMMDD000001_kisir_flag.sql`

- [ ] **Step 1: Migration dosyası yaz**

```sql
-- Migration: kisir flag + hayvan_kisir_isaretle RPC
BEGIN;

-- 1. Kolon ekle
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kisir boolean DEFAULT false;

-- 2. RPC: kısır işaretle/kaldır
CREATE OR REPLACE FUNCTION public.hayvan_kisir_isaretle(
  p_hayvan_id text,
  p_kisir boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_islem_id text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  IF v_hayvan.kisir = p_kisir THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Zaten bu durumda');
  END IF;

  UPDATE public.hayvanlar SET kisir = p_kisir WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
  VALUES (
    v_islem_id,
    CASE WHEN p_kisir THEN 'KISIR_ISARETLE' ELSE 'KISIR_KALDIR' END,
    p_hayvan_id,
    jsonb_build_object(
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'onceki',jsonb_build_object('kisir',v_hayvan.kisir))
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

END;
```

- [ ] **Step 2: Commit**

```bash
cd /root/egesut-erp1
git add supabase/migrations/*kisir*
git commit -m "migration: kisir flag + hayvan_kisir_isaretle RPC"
git push origin main
```

- [ ] **Step 3: GitHub Actions kontrol**

```bash
sleep 15 && gh run list --limit 3
```

Migration başarılıysa devam. Başarısızsa `gh run view --log-failed` ile hatayı oku ve düzelt.

---

### Task 2: Hayvan Kartında Kısır Toggle

**Files:**
- Modify: `js/ui.js` — hayvan kartı özet sekmesinde kısır toggle butonu

- [ ] **Step 1: Hayvan kartı özet tabında kısır toggle ekle**

`js/ui.js` dosyasında `_detOzetHtml()` veya detay kartı render eden fonksiyonu bul (hayvan kartı özet tab'ı). Padok değiştir butonunun altına kısır toggle ekle:

```html
<div style="margin-top:8px">
  <button class="btn ${a.kisir?'btn-warn':'btn-outline'}" onclick="toggleKisir('${a.id}',${!a.kisir})">
    ${a.kisir ? '🔴 Kısır — Satılabilir' : '⚪ Kısır İşaretle'}
  </button>
</div>
```

- [ ] **Step 2: `toggleKisir()` fonksiyonu yaz**

`padokDegistir()` fonksiyonunun hemen altına (`js/ui.js`):

```javascript
async function toggleKisir(hayvanId, yeniDurum) {
  try {
    const res = await rpc('hayvan_kisir_isaretle', { p_hayvan_id: hayvanId, p_kisir: yeniDurum });
    if (res && res.ok) {
      const hayvanlar = getState('animals');
      const idx = hayvanlar.findIndex(x => x.id === hayvanId);
      if (idx !== -1) {
        hayvanlar[idx] = { ...hayvanlar[idx], kisir: yeniDurum };
        setState('animals', [...hayvanlar]);
      }
      toast(yeniDurum ? '🔴 Kısır olarak işaretlendi' : '✅ Kısır işareti kaldırıldı');
      showDet(hayvanId);
    } else {
      toast(`⚠️ ${res?.error || 'İşlem başarısız'}`, true);
    }
  } catch (e) {
    toast(`⚠️ ${e.message}`, true);
  }
}
```

- [ ] **Step 3: Commit**

```bash
cd /root/egesut-erp1
git add js/ui.js
git commit -m "feat: hayvan kartında kısır toggle butonu"
git push origin main
```

---

### Task 3: Sürü Listesinde Kısır Filtre

**Files:**
- Modify: `js/ui.js` — `loadAnimals()` veya `renderAnimals()` fonksiyonuna filtre
- Modify: `index.html` — filtre butonları alanına kısır butonu (varsa)

- [ ] **Step 1: Sürü listesinde kısır badge göster**

`_animalTagsHtml()` fonksiyonunda (hayvan kartları render) kısır badge ekle:

```javascript
// Mevcut badge'lerin sonuna:
if (a.kisir) gebeBadge += ' <span class="badge badge-warn" style="font-size:0.7em">🔴 Kısır</span>';
```

- [ ] **Step 2: Kısır filtre butonu ekle**

Sürü tab'ındaki filtre butonları arasına (grup/padok filtrelerinin yanına):

```html
<button class="fil-btn" onclick="filterKisir()" id="btn-kisir-fil">🔴 Kısır</button>
```

- [ ] **Step 3: `filterKisir()` fonksiyonu yaz**

```javascript
let _kisirFiltre = false;
function filterKisir() {
  _kisirFiltre = !_kisirFiltre;
  document.getElementById('btn-kisir-fil')?.classList.toggle('on', _kisirFiltre);
  renderAnimals(_kisirFiltre ? _A.filter(a => a.kisir) : _A);
}
```

- [ ] **Step 4: Syntax check**

```bash
node --check /root/egesut-erp1/js/ui.js 2>&1 || echo "SYNTAX ERROR"
```

- [ ] **Step 5: Commit**

```bash
cd /root/egesut-erp1
git add js/ui.js index.html
git commit -m "feat: sürü listesinde kısır badge + filtre"
git push origin main
```

---

### Task 4: İşlem Geçmişi Desteği

**Files:**
- Modify: `js/ui.js` — ICO ve ETIKET sabitlerine kısır tip ekleme

- [ ] **Step 1: ICO ve ETIKET map'lerine kısır tiplerini ekle**

`js/ui.js` içinde iki yerde ICO/ETIKET sabitleri var (~satır 689 ve ~916). Her ikisine de ekle:

```javascript
// ICO map'ine ekle:
'KISIR_ISARETLE':'🔴','KISIR_KALDIR':'⭕'

// ETIKET map'ine ekle:
'KISIR_ISARETLE':'Kısır İşareti','KISIR_KALDIR':'Kısır Kaldırıldı'
```

- [ ] **Step 2: hayvan_durum_view güncelle (varsa)**

Eğer `hayvan_durum_view` SQL view'ı `kisir` kolonunu içermiyorsa, migration ile ekle. İçeriyorsa bu adımı atla.

```bash
cd /root/egesut-erp1
grep -l "hayvan_durum_view" supabase/migrations/*.sql | tail -1
# View'ın mevcut tanımını oku ve kisir ekle
```

- [ ] **Step 3: Commit**

```bash
cd /root/egesut-erp1
git add js/ui.js supabase/migrations/*
git commit -m "feat: kısır işlem geçmişi desteği (ICO + ETIKET)"
git push origin main
```

---

## Acceptance Criteria

1. `hayvanlar` tablosunda `kisir` boolean kolonu var
2. Hayvan kartında kısır toggle butonu çalışıyor
3. Kısır hayvanlar sürü listesinde `🔴 Kısır` badge'i ile görünüyor
4. Sürü listesinde kısır filtre butonu var ve çalışıyor
5. `islem_log`'da `KISIR_ISARETLE` / `KISIR_KALDIR` tipleri yazılıyor
6. İşlem geçmişinde kısır kayıtları uygun ikon ve etiketle görünüyor
