# Tohumlama Event Stack & Gebelik Tabı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tohumlama kayıtlarını değiştirilemez event'lere dönüştür; sadece son tohumlama aktif olsun; gebelik ataması gebelik tabına taşınsın.

**Architecture:**
Her tohumlama bir event'tir. Yeni tohumlama eklenince önceki "Bekliyor" kayıtlar otomatik "Boş" kapanır. UI'da önceki tohumlamalar readonly listelenir; sadece son tohumlama geri alınabilir. Gebelik ataması yeni `tohumlama_sonuc_gebe` RPC ile gebelik tabından yapılır.

**Tech Stack:** Vanilla JS, Supabase RPC, IndexedDB, `idbGetAll`, `getState`, `pullTables`+`renderSafe`

---

## Dosya Haritası

| Dosya | Değişiklik |
|---|---|
| `supabase/migrations/YYYYMMDD_tohumlama_event_stack.sql` | Yeni migration — 2 RPC güncelle/ekle |
| `js/api.js` | `tohumlama_sonuc_gebe` wrapper ekle |
| `js/ui.js` | `openTohDet` frozen kontrolü, gebelik tabı render |
| `js/forms.js` | `gebeIsaretKaydet` → yeni RPC, gebelik submit handler |
| `index.html` | Gebelik tabı HTML (liste + modal) |

---

## Task 1: DB — `tohumlama_kaydet` RPC: Önceki Bekliyor → Otomatik Boş

**Files:**
- Create: `supabase/migrations/20260326000030_tohumlama_event_stack.sql`

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- Migration: tohumlama event stack
-- Etkiler: tohumlama_kaydet RPC (önceki Bekliyor→Boş), tohumlama_sonuc_gebe yeni RPC
-- Geri alınabilir: hayır (RPC replace)

BEGIN;

-- =====================================================
-- 1. tohumlama_kaydet güncelleme
--    Yeni tohumlama eklenince önceki Bekliyor → Boş
-- =====================================================
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id text,
  p_sperma text,
  p_tarih date DEFAULT CURRENT_DATE,
  p_tohumlayan text DEFAULT NULL,
  p_hekim_id text DEFAULT NULL,
  p_irk_bilgisi text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_toh_id uuid;
  v_islem_id uuid;
BEGIN
  -- Hayvan kontrolü
  SELECT * INTO v_hayvan FROM public.hayvanlar
  WHERE id::text = p_hayvan_id OR kupe_no = p_hayvan_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan bulunamadı');
  END IF;
  IF v_hayvan.aktif = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pasif hayvana tohumlama yapılamaz');
  END IF;
  IF v_hayvan.cinsiyet != 'Dişi' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Erkek hayvana tohumlama yapılamaz');
  END IF;

  -- Yaş kontrolü (12 ay+)
  IF v_hayvan.dogum_tarihi IS NOT NULL AND
     (CURRENT_DATE - v_hayvan.dogum_tarihi) < 365 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan 12 aydan küçük');
  END IF;

  -- Mevcut Bekliyor tohumlamaları Boş yap (event stack kuralı)
  UPDATE public.tohumlama
  SET sonuc = 'Boş'
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor';

  -- Yeni tohumlama kaydı
  INSERT INTO public.tohumlama (
    hayvan_id, sperma, tarih, tohumlayan, hekim_id,
    irk_bilgisi, sonuc, deneme_no
  )
  SELECT
    p_hayvan_id, p_sperma, p_tarih, p_tohumlayan, p_hekim_id,
    p_irk_bilgisi, 'Bekliyor',
    COALESCE((
      SELECT MAX(deneme_no) FROM public.tohumlama
      WHERE hayvan_id = p_hayvan_id
    ), 0) + 1
  RETURNING id INTO v_toh_id;

  -- islem_log kayıt (ref_id dolu — geri alma için)
  INSERT INTO public.islem_log (tip, ref_id, payload)
  VALUES (
    'TOHUMLAMA',
    v_toh_id::text,
    jsonb_build_object(
      'hayvan_id', p_hayvan_id,
      'sperma', p_sperma,
      'tarih', p_tarih
    )
  )
  RETURNING id INTO v_islem_id;

  -- Gorev_log: 21. gün kontrol
  INSERT INTO public.gorev_log (tip, hayvan_id, tarih, ref_id)
  VALUES ('TOHUMLAMA_KONTROL_21', p_hayvan_id, p_tarih + 21, v_toh_id::text);

  -- Gorev_log: 35. gün kontrol
  INSERT INTO public.gorev_log (tip, hayvan_id, tarih, ref_id)
  VALUES ('TOHUMLAMA_KONTROL_35', p_hayvan_id, p_tarih + 35, v_toh_id::text);

  -- Stok düş (sperma)
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok', true,
    'tohumlama_id', v_toh_id,
    'islem_id', v_islem_id
  );
END;
$$;

-- =====================================================
-- 2. tohumlama_sonuc_gebe — yeni RPC
--    Gebelik tabından çağrılır, sadece son tohumlama
-- =====================================================
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh record;
  v_son_toh_id text;
BEGIN
  -- Tohumlama kaydını bul
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir
  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  -- Bu hayvanın son tohumlaması mı?
  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  -- Gebe ata
  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;

  -- Hayvan durumunu güncelle
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Gebe'
  WHERE id::text = v_toh.hayvan_id OR kupe_no = v_toh.hayvan_id;

  -- islem_log
  INSERT INTO public.islem_log (tip, ref_id, payload)
  VALUES (
    'GEBE_ATAMA',
    p_tohumlama_id,
    jsonb_build_object('hayvan_id', v_toh.hayvan_id)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

COMMIT;
```

- [ ] **Step 2: Migration'ı DB'ye uygula**

```sql
-- execute_sql ile çalıştır (apply_migration kullanma)
-- Yukarıdaki SQL'i mcp__supabase__execute_sql ile çalıştır
```

- [ ] **Step 3: Doğrula**

```sql
SELECT proname FROM pg_proc
WHERE proname IN ('tohumlama_kaydet', 'tohumlama_sonuc_gebe')
ORDER BY proname;
-- Beklenen: her ikisi de döner
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/
git commit -m "feat(db): tohumlama event stack — önceki Bekliyor→Boş, tohumlama_sonuc_gebe RPC"
```

---

## Task 2: api.js — `tohumlama_sonuc_gebe` Wrapper

**Files:**
- Modify: `js/api.js` — `RPC_INVALIDATION_MAP`'e ekle

- [ ] **Step 1: `api.js`'de `RPC_INVALIDATION_MAP`'i oku, `tohumlama_sonuc_gebe` satırını ekle**

`api.js` içinde `RPC_INVALIDATION_MAP` (satır ~200) bul. Şu satırı ekle:
```js
tohumlama_sonuc_gebe: ['hayvanlar','tohumlama','islem_log'],
```

- [ ] **Step 2: Syntax kontrol**

```bash
node --check js/api.js
```
Beklenen: OK

- [ ] **Step 3: Commit**

```bash
git add js/api.js
git commit -m "feat(api): tohumlama_sonuc_gebe RPC invalidation eklendi"
```

---

## Task 3: ui.js — `openTohDet` Frozen Kontrolü

**Files:**
- Modify: `js/ui.js` — `openTohDet` fonksiyonu (satır ~2159-2226)

Kural: Hayvanın bir tohumlaması tıklandığında, bu tohumlama o hayvanın **son tohumlaması** ise butonlar gösterilir; değilse tüm butonlar gizlenir, sadece bilgi gösterilir.

- [ ] **Step 1: `openTohDet` fonksiyonunu oku (ui.js:2159-2226)**

Mevcut kodu gör, hangi butonlar var tespit et.

- [ ] **Step 2: Son tohumlama kontrolü ekle**

`openTohDet` fonksiyonunun başına, `tohumlama` listesi alındıktan sonra şu kontrolü ekle:

```js
// Son tohumlama mu kontrolü
const tumTohlar = await idbGetAll('tohumlama');
const hayvanTohlar = tumTohlar
  .filter(t2 => t2.hayvan_id === t.hayvan_id)
  .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
const sonTohumlama = hayvanTohlar[0];
const isSonToh = sonTohumlama && sonTohumlama.id === id;
```

- [ ] **Step 3: Buton görünürlüklerini `isSonToh`'a bağla**

Mevcut buton render kodlarını bul. Her buton için:
```js
// Geri al butonu — sadece son tohumlamada
if (td2GeriAlBtn) {
  td2GeriAlBtn.style.display = isSonToh && islemKayit ? 'block' : 'none';
  if (isSonToh && islemKayit) {
    td2GeriAlBtn.onclick = () => openGeriAl(
      islemKayit.id,
      `${hayvanLabel} — ${t.sperma||'?'} (${fmtTarih(t.tarih)})`
    );
  }
}
```

Tohumlama tabındaki Gebe/Boş butonları varsa tamamen kaldır (gebelik tabına taşınıyor).

- [ ] **Step 4: Önceki tohumlamalar için "readonly" bilgi mesajı**

`isSonToh === false` ise modal içine bilgi notu ekle:
```js
if (!isSonToh) {
  // Bir info banner ekle
  const info = document.createElement('p');
  info.style.cssText = 'color:var(--ink3);font-size:.85rem;text-align:center;margin:8px 0';
  info.textContent = 'Bu kayıt geçmişe ait — sadece bilgi amaçlı görüntüleniyor.';
  // Modal içeriğinin üstüne ekle
}
```

- [ ] **Step 5: Syntax kontrol**

```bash
node --check js/ui.js
```

- [ ] **Step 6: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): tohumlama detay — sadece son tohumlama aktif, öncekiler frozen"
```

---

## Task 4: index.html + ui.js — Gebelik Tabı

**Files:**
- Modify: `index.html` — gebelik tab HTML
- Modify: `js/ui.js` — gebelik tab render fonksiyonu

Gebelik tabı: `tohumlama.sonuc = 'Bekliyor'` olan ve hayvanın son tohumlaması olan kayıtları listeler. Her satırda "Gebe Ata" butonu.

- [ ] **Step 1: `index.html`'de gebelik tabının mevcut HTML'ini bul**

`index.html`'de `gebelik` veya `gebe` ile ilgili tab/section içeriğini oku. Mevcut yapı neyse ona göre devam et.

- [ ] **Step 2: Gebelik tabına liste HTML'i ekle**

Mevcut gebelik tab içeriğine ekle (yoksa oluştur):
```html
<!-- Gebelik Tab — Son Tohumlamalar Listesi -->
<div id="gebe-liste-wrap">
  <div id="gebe-liste"></div>
</div>
```

- [ ] **Step 3: `ui.js`'e `renderGebeListe` fonksiyonu ekle**

```js
async function renderGebeListe() {
  const wrap = document.getElementById('gebe-liste');
  if (!wrap) return;
  const tumTohlar = await idbGetAll('tohumlama');
  const hayvanlar = getState('animals') || [];

  // Her hayvan için son tohumlama
  const hayvanSonToh = {};
  tumTohlar
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .forEach(t => {
      if (!hayvanSonToh[t.hayvan_id]) hayvanSonToh[t.hayvan_id] = t;
    });

  // Sadece Bekliyor durumundaki son tohumlamalar
  const bekleyenler = Object.values(hayvanSonToh)
    .filter(t => t.sonuc === 'Bekliyor');

  if (!bekleyenler.length) {
    wrap.innerHTML = '<p style="color:var(--ink3);text-align:center;padding:24px">Bekleyen tohumlama yok</p>';
    return;
  }

  wrap.innerHTML = bekleyenler.map(t => {
    const h = hayvanlar.find(h => h.id === t.hayvan_id || h.kupe_no === t.hayvan_id);
    const kupe = h?.kupe_no || t.hayvan_id;
    const gun = t.tarih ? Math.floor((Date.now() - new Date(t.tarih)) / 86400000) : '?';
    return `
      <div class="card" style="margin-bottom:8px;padding:12px 16px;display:flex;align-items:center;justify-content:space-between;gap:8px">
        <div>
          <strong>${kupe}</strong>
          <span style="color:var(--ink3);font-size:.85rem;margin-left:8px">${t.sperma||'?'} · ${fmtTarih(t.tarih)} · ${gun} gün</span>
        </div>
        <button class="btn" style="background:var(--green);color:#fff;white-space:nowrap"
          onclick="gebeAta('${t.id}','${kupe}')">🤰 Gebe Ata</button>
      </div>`;
  }).join('');
}
```

- [ ] **Step 4: `gebeAta` fonksiyonu ekle**

```js
async function gebeAta(tohId, kupe) {
  if (!confirm(`${kupe} — gebe olarak işaretlensin mi?`)) return;
  try {
    await rpc('tohumlama_sonuc_gebe', { p_tohumlama_id: tohId });
    toast('✅ Gebe olarak işaretlendi');
    await pullTables(['hayvanlar','tohumlama','islem_log']);
    renderSafe();
    renderGebeListe();
  } catch(e) {
    toast('❌ ' + e.message, true);
  }
}
```

- [ ] **Step 5: Gebelik tabı açıldığında `renderGebeListe()` çağrılsın**

`js/app.js` veya `ui.js`'de tab switch handler'ını bul. Gebelik tabı aktif olunca:
```js
renderGebeListe();
```

- [ ] **Step 6: Syntax kontrol**

```bash
node --check js/ui.js && node --check js/app.js
```

- [ ] **Step 7: Commit**

```bash
git add index.html js/ui.js js/app.js
git commit -m "feat(ui): gebelik tabı — son tohumlamalar listesi + gebe ata butonu"
```

---

## Task 5: forms.js — Eski `gebeIsaretKaydet` Temizliği

**Files:**
- Modify: `js/forms.js`

- [ ] **Step 1: `gebeIsaretKaydet` ve `tohSonucGuncelle` çağrılarını bul**

```bash
grep -n "gebeIsaretKaydet\|tohSonucGuncelle" js/forms.js js/ui.js
```

- [ ] **Step 2: Doğrudan REST yazma path'lerini kaldır**

`gebeIsaretKaydet` içindeki `write()` REST PATCH çağrısını kaldır veya devre dışı bırak.
Gebe ataması artık `gebeAta()` → `tohumlama_sonuc_gebe` RPC üzerinden yapılıyor.

- [ ] **Step 3: `tohSonucGuncelle`'deki `db.from().update()` çağrısını kaldır**

`ui.js`'deki `tohSonucGuncelle` fonksiyonunu komple kaldır (Task 3'te `isSonToh` kontrolü zaten eklendi, bu fonksiyon artık kullanılmıyor).

- [ ] **Step 4: Syntax kontrol**

```bash
node --check js/forms.js && node --check js/ui.js
```

- [ ] **Step 5: Commit**

```bash
git add js/forms.js js/ui.js
git commit -m "refactor: eski REST yazma path'leri kaldırıldı — tohumlama sadece RPC"
```

---

## Task 6: SONARCLOUD_REMEDIATION_PLAN.md Güncelleme

**Files:**
- Modify: `SONARCLOUD_REMEDIATION_PLAN.md`

- [ ] **Step 1: Yeni bir oturum bölümü ekle**

`SONARCLOUD_REMEDIATION_PLAN.md`'ye `### Oturum 2026-03-26 (Devamı — Tohumlama Event Stack)` başlığı altında:

```markdown
| Tohumlama Event Stack | [commit] | `supabase/migrations/030`, `js/ui.js`, `js/forms.js`, `js/api.js`, `index.html` | Tohumlama = immutable event. Yeni tohumlama → önceki Bekliyor otomatik Boş. Sadece son tohumlama aktif. Gebelik ataması gebelik tabına taşındı. tohumlama_sonuc_gebe RPC eklendi. |
```

- [ ] **Step 2: Commit**

```bash
git add SONARCLOUD_REMEDIATION_PLAN.md
git commit -m "docs: tohumlama event stack plan dosyasına işlendi"
```

---

## Self-Review

**Spec coverage:**
- ✅ Yeni tohumlama → önceki Bekliyor otomatik Boş (Task 1)
- ✅ Önceki tohumlamalar frozen/readonly (Task 3)
- ✅ Sadece son tohumlama üzerinde geri al (Task 3)
- ✅ Geri al = stack pop, bağlı kayıtlar temizlenir (mevcut `geri_al` RPC zaten gorev_log siliyor — doğrula)
- ✅ Gebelik ataması gebelik tabından (Task 4)
- ✅ `tohumlama_sonuc_gebe` RPC (Task 1 + Task 2)
- ✅ Eski REST yazma path'leri kaldırıldı (Task 5)

**Eksik kontrol — `geri_al` RPC'nin gorev_log sildiğini doğrula:**
Task 1 Step 3'te RPC doğrulamasına ek olarak:
```sql
SELECT prosrc FROM pg_proc WHERE proname = 'geri_al';
-- gorev_log DELETE satırı var mı kontrol et
```
Yoksa Task 1 migration'ına `geri_al` güncellemesi ekle.
