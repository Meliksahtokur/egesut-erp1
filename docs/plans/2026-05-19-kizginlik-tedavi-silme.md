# Kızgınlık Tedavi + Silme — Implementation Plan

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Kızgınlık kayıtlarına silme (RPC + confirm) ve tedavi bağlantısı (cases modülüne entegre) eklemek.

**Architecture:** Mevcut `kizginlik_log` tablosuna `tedavi_case_id` (FK → cases) ve `cozuldu` kolonları eklenir. Kızgınlık listesinden "🏥 Tedavi" butonu mevcut `m-disease` modal'ını açar, dropdown sadece **Üreme** kategorisi hastalıkları gösterir. Vaka kapatılınca trigger ile kızgınlık da kapanır. Silme için yeni `kizginlik_sil()` RPC'si + UI.

**Tech Stack:** PostgreSQL (Supabase), Vanilla JS, IndexedDB

---

## Ön Bilgiler

### Mevcut Üreme Kategorisi Hastalıkları (6 adet)

| Diseases | category |
|---|---|
| Metrit | Üreme |
| Endometrit | Üreme |
| Pyometra | Üreme |
| Retensiyo Sekundinarum | Üreme |
| Kistik Over | Üreme |
| Anoestrus | Üreme |

### kizginlik_log Mevcut Şema

```sql
id          text PRIMARY KEY,
hayvan_id   text,
tarih       date,
belirti     text,
notlar      text,
olusturma   timestamptz DEFAULT now()
```

### Kilit Dosyalar

| Dosya | Role |
|-------|------|
| `supabase/migrations/99999999999999_ground_truth.sql` | Canonical DB referansı |
| `js/ui.js` | `_uremeKizginlik` (kızgınlık listesi render), `loadGecmis`, offline queue |
| `js/forms.js` | `submitCase` (vaka açma), `loadDiseasesDropdown` |
| `js/app.js` | Routing, RPC trigger |
| `js/api.js` | `RPC_TABLES`, `DB_VER` |

---

## Task 1: Migration — DB Değişiklikleri

**TDD scenario:** Trivial change (SQL migration, test by deploying)

**Files:**
- Create: `supabase/migrations/20260519000002_kizginlik_tedavi_sil.sql`

**Step 1: Migration içeriğini yaz**

İçerik:

```sql
-- ============================================================
-- kizginlik_tedavi_sil
-- kizginlik_log → cases bağlantısı + silme RPC
-- ============================================================

BEGIN;

-- 1. kizginlik_log'a yeni kolonlar
ALTER TABLE public.kizginlik_log
  ADD COLUMN IF NOT EXISTS tedavi_case_id uuid REFERENCES public.cases(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cozuldu       boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.kizginlik_log.tedavi_case_id IS 'Opsiyonel vaka bağlantısı — cases.id FK';
COMMENT ON COLUMN public.kizginlik_log.cozuldu        IS 'true = tedavi edildi / kapatıldı';

CREATE INDEX IF NOT EXISTS kizginlik_log_cozuldu_idx ON public.kizginlik_log(cozuldu);

-- 2. Silme RPC
CREATE OR REPLACE FUNCTION public.kizginlik_sil(p_kayit_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan_id text;
  v_case_id   uuid;
BEGIN
  -- Kaydı ve bağlı case_id'yi oku
  SELECT hayvan_id, tedavi_case_id INTO v_hayvan_id, v_case_id
  FROM public.kizginlik_log WHERE id = p_kayit_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Kayıt bulunamadı');
  END IF;

  -- Kızgınlık kaydını sil (trigger islem_log yazmaz — DELETE trigger yok)
  DELETE FROM public.kizginlik_log WHERE id = p_kayit_id;

  -- Bağlı vaka varsa onu da kapat (veri tutarlılığı)
  IF v_case_id IS NOT NULL THEN
    UPDATE public.cases
    SET status = 'closed', closed_at = now()
    WHERE id = v_case_id AND status = 'active';
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_sil(text) TO anon, authenticated;

-- 3. Vaka kapanınca kızgınlığı da kapat — trigger
CREATE OR REPLACE FUNCTION public._kizginlik_case_close()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'closed' AND OLD.status = 'active' THEN
    UPDATE public.kizginlik_log
    SET cozuldu = true
    WHERE tedavi_case_id = NEW.id AND cozuldu = false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_kizginlik_case_close ON public.cases;
CREATE TRIGGER trg_kizginlik_case_close
  AFTER UPDATE OF status ON public.cases
  FOR EACH ROW
  WHEN (NEW.status = 'closed' AND OLD.status = 'active')
  EXECUTE FUNCTION public._kizginlik_case_close();

COMMIT;
```

**Step 2: Deploy**

```bash
supabase db push
```
Veya Supabase Dashboard → SQL Editor → yapıştır → çalıştır.

---

## Task 2: js/ui.js — _uremeKizginlik Render (Sil + Tedavi Butonları)

**TDD scenario:** Trivial change (UI modification)

**Files:**
- Modify: `js/ui.js:1257-1274`

**Step 1: Mevcut kodu oku**

```js
// 1257-1273 arası
async function _uremeKizginlik(el){
  const list=await idbGetAll('kizginlik_log');
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  el.innerHTML=...
    (list.length?list.map(k=>{
      const h=getState('animals').find(a=>a.id===k.hayvan_id);
      const kupe=h?.kupe_no||h?.devlet_kupe||k.hayvan_id;
      return `<div class="hist-row">
        <div class="hist-dot" style="background:#e74c3c;cursor:pointer" onclick="openDet('${k.hayvan_id}')"></div>
        <div class="hist-main" style="cursor:pointer" onclick="openDet('${k.hayvan_id}')">
          <div class="hist-title">🔴 ${kupe} — ${k.belirti||'Kızgınlık'}</div>
          <div class="hist-sub">${k.tarih} ${k.notlar?'· '+k.notlar:''}</div>
        </div>
        <button style="background:var(--blue);color:#fff;white-space:nowrap;flex-shrink:0;padding:2px 5px;font-size:.62rem;min-width:auto;line-height:1.1;border-radius:4px;border:none;cursor:pointer;font-weight:700"
          onclick="event.stopPropagation();openMWithHayvan('m-insem','i-hid','${kupe}')">💉 Tohumla</button>
      </div>`;
    }).join(''):'<div class="empty"><div class="empty-ico">🔴</div>Kızgınlık kaydı yok</div>');
}
```

**Step 2: Değişikliği uygula**

Aynı kodu şu şekilde değiştir (değişen satırlar: `hist-sub` satırı, buton satırı + yeni butonlar):

```js
async function _uremeKizginlik(el){
  const list=await idbGetAll('kizginlik_log');
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-kizginlik')">🔴 Kızgınlık Ekle</button></div>`+
    (list.length?list.map(k=>{
      const h=getState('animals').find(a=>a.id===k.hayvan_id);
      const kupe=h?.kupe_no||h?.devlet_kupe||k.hayvan_id;
      const cozulduKulp=k.cozuldu
        ? `<span style="font-size:.6rem;color:var(--green);background:rgba(78,154,42,.1);border-radius:4px;padding:1px 5px;margin-left:4px">✅ Tedavi</span>`
        : '';
      return `<div class="hist-row">
        <div class="hist-dot" style="background:#e74c3c;cursor:pointer" onclick="openDet('${k.hayvan_id}')"></div>
        <div class="hist-main" style="cursor:pointer" onclick="openDet('${k.hayvan_id}')">
          <div class="hist-title">🔴 ${kupe} — ${k.belirti||'Kızgınlık'} ${cozulduKulp}</div>
          <div class="hist-sub">${k.tarih} ${k.notlar?'· '+k.notlar:''}</div>
        </div>
        <div style="display:flex;gap:3px;flex-shrink:0;align-items:center">
          <button style="background:var(--blue);color:#fff;padding:2px 5px;font-size:.62rem;border-radius:4px;border:none;cursor:pointer;font-weight:700"
            onclick="event.stopPropagation();openMWithHayvan('m-insem','i-hid','${kupe}')">💉 Tohumla</button>
          <button style="background:rgba(42,107,181,.15);color:var(--blue);padding:2px 5px;font-size:.62rem;border-radius:4px;border:none;cursor:pointer;font-weight:700;white-space:nowrap"
            onclick="event.stopPropagation();kizginlikTedaviAc('${k.id}','${kupe}')">🏥 Tedavi</button>
          <button style="background:rgba(192,50,26,.1);color:var(--red2);padding:2px 5px;font-size:.6rem;border-radius:4px;border:none;cursor:pointer;font-weight:700;line-height:1"
            onclick="event.stopPropagation();kizginlikSil('${k.id}')">🗑️</button>
        </div>
      </div>`;
    }).join(''):'<div class="empty"><div class="empty-ico">🔴</div>Kızgınlık kaydı yok</div>');
}
```

**Değişiklik özeti:**
- `cozuldu=true` ise başlıkta ✅ Tedavi etiketi göster
- Butonlar tek bir `div` içine alındı (flex container)
- Mevcut 💉 Tohumla butonu korundu
- Yeni: 🏥 Tedavi butonu → `kizginlikTedaviAc(id, kupe)` çağırır
- Yeni: 🗑️ Sil butonu → `kizginlikSil(id)` çağırır

**Step 3: Aynı dosyada `kizginlikTedaviAc` ve `kizginlikSil` fonksiyonlarını ekle**

`kizginlikYoktu` fonksiyonundan hemen sonra (yaklaşık 274. satır) ekle:

```js
// ── Kızgınlık → Tedavi Aç ────────────────────
function kizginlikTedaviAc(kayitId, kupe) {
  // Mevcut m-disease modal'ını aç, hayvanı pre-fill et
  openMWithHayvan('m-disease', 'd-hid', kupe);
  // kizginlik_id'yi global'de sakla — submitCase sonrası bağlantı için
  globalThis._kizginlikTedaviId = kayitId;
}

// ── Kızgınlık Sil ────────────────────────────
async function kizginlikSil(kayitId) {
  if (!confirm('Bu kızgınlık kaydını silmek istediğinize emin misiniz?')) return;
  try {
    const res = await rpc('kizginlik_sil', { p_kayit_id: kayitId });
    if (!res?.ok) throw new Error(res?.hata || 'Silme başarısız');
    toast('🗑️ Kızgınlık kaydı silindi');
    await pullTables(['kizginlik_log']);
    if (typeof loadUreme === 'function') loadUreme('kizginlik');
  } catch (e) {
    toast('❌ ' + e.message, true);
  }
}
```

---

## Task 3: js/forms.js — submitCase'de kızgınlık bağlantısı + Üreme filtresi

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/forms.js:236-261` (loadDiseasesDropdown)
- Modify: `js/forms.js:287-298` (submitCase)

**Step 1: loadDiseasesDropdown'a Üreme filtresi ekle**

Mevcut `loadDiseasesDropdown` tüm kategorileri gösterir. `_kizginlikTedaviId` global'de varsa sadece Üreme kategorisini filtrele:

```js
async function loadDiseasesDropdown() {
  const sel = g('d-disease-id');
  if (!sel) return;
  const list = await idbGetAll('diseases');

  // Kızgınlık tedavi akışından geliniyorsa sadece Üreme hastalıklarını göster
  const sadeceUreme = !!globalThis._kizginlikTedaviId;
  const filtrelenmis = sadeceUreme
    ? list.filter(d => (d.category || '').toLowerCase() === 'üreme')
    : list;

  // Kategoriye göre grupla
  const grouped = {};
  filtrelenmis.forEach(d => {
    const cat = d.category || 'Diğer';
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(d);
  });
  sel.innerHTML = '<option value="">— Hastalık seçin —</option>';
  Object.keys(grouped).sort().forEach(cat => {
    const og = document.createElement('optgroup');
    og.label = cat;
    grouped[cat].forEach(d => {
      const o = document.createElement('option');
      o.value = d.id;
      o.textContent = d.name;
      o.dataset.category = d.category || '';
      og.appendChild(o);
    });
    sel.appendChild(og);
  });

  // Sadece Üreme ise dropdown'a bilgi notu ekle
  if (sadeceUreme) {
    const info = document.createElement('div');
    info.style.cssText = 'font-size:.68rem;color:var(--ink3);padding:4px 0;text-align:center';
    info.textContent = '🔴 Kızgınlık tedavisi için üreme hastalıkları listeleniyor';
    sel.parentNode.insertBefore(info, sel.nextSibling);
    // Önceki eklenmişse temizle
    const prev = sel.parentNode.querySelector('.kizginlik-info');
    if (prev) prev.remove();
    info.className = 'kizginlik-info';
  }
}
```

**Step 2: submitCase'de kızgınlık bağlantısını kur**

Başarılı case creation sonrası (296. satır civarı, `await loadDrugsCache()` ve `_drugsCache = []` satırlarından sonra):

```js
// Kızgınlık tedavi bağlantısı
if (globalThis._kizginlikTedaviId) {
  const kid = globalThis._kizginlikTedaviId;
  globalThis._kizginlikTedaviId = null; // temizle
  try {
    await rpc('kizginlik_tedavi_baglanti_kur', {
      p_kayit_id: kid,
      p_case_id:  res.case_id
    });
  } catch (e) {
    console.warn('Kızgınlık-case bağlantısı kurulamadı:', e);
  }
}
```

Ve modal kapatılırken/düzenleme açılırken `_kizginlikTedaviId` temizlenmeli (closeDisease'de):

```js
function closeDisease() {
  _editMode = false;
  globalThis._kizginlikTedaviId = null; // 🔴 temizle
  // ... mevcut kod
}
```

---

## Task 4: Yeni RPC — kizginlik_tedavi_baglanti_kur

**TDD scenario:** Trivial change (SQL migration'a ek)

**Files:**
- Modify: `supabase/migrations/20260519000002_kizginlik_tedavi_sil.sql`

**Step 1: Task 1'deki migration'a şu RPC'yi ekle (BEGIN/COMMIT bloğunun içine):**

```sql
-- 4. Kızgınlık ↔ Vaka bağlantı RPC'si
CREATE OR REPLACE FUNCTION public.kizginlik_tedavi_baglanti_kur(p_kayit_id text, p_case_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.kizginlik_log
  SET tedavi_case_id = p_case_id
  WHERE id = p_kayit_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_tedavi_baglanti_kur(text, uuid) TO anon, authenticated;
```

---

## Task 5: js/api.js — DB_VER + RPC_TABLES + offline queue

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/api.js` (tüm değişiklikler)

**Step 1: DB_VER 16 → 17**

```js
const DB_VER  = 17;
```

**Step 2: RPC_TABLES'a yeni RPC'leri ekle**

```js
const RPC_TABLES = {
  // ... mevcut ...
  kizginlik_sil:                ['kizginlik_log'],
  kizginlik_tedavi_baglanti_kur:['kizginlik_log'],
  // ... mevcut ...
};
```

---

## Task 6: js/ui.js — Offline Queue RPC_MAP + buildRpcParams

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/ui.js:3520-3528` (RPC_MAP)
- Modify: `js/ui.js:3564-...` (buildRpcParams)

**Step 1: RPC_MAP'e kizginlik_log için DELETE eylemi ekle**

```js
// 3525. satır:
kizginlik_log: { POST: 'kizginlik_kaydet', DELETE: 'kizginlik_sil' },
```

**Step 2: buildRpcParams'e kizginlik_sil durumunu ekle**

```js
case 'kizginlik_sil':
  return {
    p_kayit_id: data.id || op.filter?.replace('id=eq.', '')
  };
```

---

## Task 7: js/ui.js — _uremeKizginlik'te cozuldu=true kayıtların görünümü

**TDD scenario:** Trivial change (UI)

**Step 1:** _uremeKizginlik'te varsayılan olarak `cozuldu=false` olanları göster. İsteğe bağlı "✅ Tedavi Edilenler" butonu ekle (opsiyonel, MVP'de atlanabilir).

MVP'de sadece başlıkta ✅ Tedavi etiketi göster, tüm kayıtlar listede kalır.

---

## Task 8: js/app.js — Kızgınlık silme sonrası UI refresh

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/app.js` (opsiyonel)

**Step 1:** `goTo()` routing'inde kızgınlık sekmesine özel bir şey gerekmez — mevcut `pg === 'ureme'` zaten `loadUreme(_curUremeTab)` çağırır. Silme sonrası `loadUreme('kizginlik')` zaten `kizginlikSil` fonksiyonunda çağrılıyor.

---

## Commit Planı

| Task | Commit Mesajı |
|------|--------------|
| Task 1 + 4 | `feat(db): kizginlik_log tedavi_case_id + cozuldu + kizginlik_sil RPC + trigger` |
| Task 2 + 6 + 7 | `feat(ui): kizginlik listesine silme ve tedavi butonlari` |
| Task 3 | `feat(forms): vaka acma modalina ureme filtresi + kizginlik baglantisi` |
| Task 5 | `chore(api): db_ver 17, rpc_tables guncellemesi` |

Veya tek commit: `feat: kizginlik tedavi-silme entegrasyonu`

---

## Test & Deploy

1. Migration deploy: Supabase Dashboard → SQL Editor → migration içeriğini yapıştır → çalıştır
2. Frontend: GitHub Pages otomatik deploy (push sonrası ~2dk)
3. Manuel test akışı:
   - Üreme → Kızgınlık sekmesini aç
   - Var olan bir kızgınlık kaydında 🗑️ tıkla → confirm → silindiğini doğrula
   - 🏥 Tedavi tıkla → sadece Üreme hastalıkları listelendiğini doğrula
   - Vaka aç → vaka detayına gir → tedavi ekle → vakayı kapat
   - Kızgınlık listesinde ✅ Tedavi etiketi göründüğünü doğrula
