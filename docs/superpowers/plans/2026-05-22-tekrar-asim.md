# Tekrar Aşım — Implementasyon Planı

> Soru varsa devam etmeden önce sor. Bulk UPDATE/DELETE içeren adımlarda onay bekle.

**Hedef:** Aynı tohumlama kaydını güncelleyerek tekrar aşım kaydet; her deneme stok düşsün, görevler son tarihten hesaplansın, geçmiş denemeler detayda görünsün.

**Etkilenen dosyalar:**
- `supabase/migrations/20260522000004_tekrar_asim.sql` (YENİ)
- `js/ui.js` — hayvan kartı badge, üreme sekmesi badge, tekrar butonu, openTohDet history
- `js/forms.js` — submitTekrarAsim fonksiyonu
- `js/api.js` — RPC_TABLES + params mapping
- `index.html` — m-insem-tekrar modal

---

## Başlamadan Önce

Sırayla oku:
```bash
cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
cat /root/egesut-erp1/.claude/rpc-reference.md
cat /root/egesut-erp1/.claude/domain-rules.md
```

Sonra bu planı oku. Net olmayan şey varsa sor.

---

## Task 1 — DB: Şema + Cycle Trigger Bug Fix

### 1a — `tohumlama` tablosuna iki kolon ekle

**Uygulama:**
```
supabase_migrate({sql: `
ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS deneme_sayisi integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS denemeler    jsonb   NOT NULL DEFAULT '[]'::jsonb;
`})
```

**Doğrulama:**
```
supabase_query({
  table: "information_schema.columns",
  filters: "table_name=eq.tohumlama&column_name=in.(deneme_sayisi,denemeler)",
  select: "column_name,data_type,column_default"
})
```
Beklenen: 2 satır dönmeli.

### 1b — Cycle trigger bug fix: GEBELIK_KONTROL tipini de kapsasın

Mevcut `tohumlama_cycle_gorevcil_iptal` trigger fonksiyonu `TOHUMLAMA_HAZIRLIK` hedefliyor ama `tohumlama_kaydet` `GEBELIK_KONTROL` tipi görev üretiyor — trigger bu görevleri kaçırıyor.

Önce mevcut fonksiyonu oku:
```bash
grep -n "tohumlama_cycle_gorevcil_iptal\|GEBELIK_KONTROL\|TOHUMLAMA_HAZIRLIK" \
  /root/egesut-erp1/supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql | head -20
```

**Uygulama** — her iki IN listesine `'GEBELIK_KONTROL'` ekleyerek fonksiyonu REPLACE et:
```
supabase_migrate({sql: `
CREATE OR REPLACE FUNCTION public.tohumlama_cycle_gorevcil_iptal()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL'
      );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.sonuc IN ('Bekliyor', 'Gebe')
     AND NEW.sonuc IN ('Boş', 'Abort') THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL'
      )
      AND (ref_tohumlama_id IS NULL OR ref_tohumlama_id = NEW.id::text);
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;
`})
```

**Doğrulama:**
```bash
grep -n "GEBELIK_KONTROL" \
  /root/egesut-erp1/supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql
```
Beklenen: ekleme görünmemeli çünkü biz migration dosyasına yazmadık; sadece DB'ye deploy ettik. Trigger'ın canlıda güncellediğini doğrulamak için:
```
supabase_query({
  table: "information_schema.routines",
  filters: "routine_name=eq.tohumlama_cycle_gorevcil_iptal",
  select: "routine_name,routine_definition",
  limit: 1
})
```
routine_definition içinde `GEBELIK_KONTROL` geçmeli.

**Commit:**
```bash
git add supabase/migrations/20260522000004_tekrar_asim.sql
git commit -m "feat(db): tohumlama deneme_sayisi+denemeler + cycle trigger GEBELIK_KONTROL fix"
```

---

## Task 2 — DB: `tohumlama_tekrar_kaydet` RPC

**Okuma:**
```bash
# tohumlama_kaydet'in tam son halini oku (referans al)
sed -n '1447,1533p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# Son migration'daki tohumlama_kaydet varsa onu da oku
grep -n "tohumlama_kaydet" \
  /root/egesut-erp1/supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql | head -5
```

**Uygulama:**
```
supabase_migrate({sql: `
CREATE OR REPLACE FUNCTION public.tohumlama_tekrar_kaydet(
  p_hayvan_id   text,
  p_tarih       date,
  p_sperma      text,
  p_hekim_id    text DEFAULT NULL,
  p_irk_bilgisi text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_toh      record;
  v_eski     jsonb;
  v_yeni_denemeler jsonb;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  -- İleri tarih kontrolü
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tarih ileri olamaz';
  END IF;

  -- Son 15 gün içinde Bekliyor tohumlama bul
  SELECT * INTO v_toh
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor'
    AND tarih >= CURRENT_DATE - INTERVAL '15 days'
  ORDER BY tarih DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Son 15 gün içinde Bekliyor tohumlama bulunamadı';
  END IF;

  -- Mevcut denemeyi denemeler dizisine ekle
  v_eski := jsonb_build_object(
    'no',       v_toh.deneme_sayisi,
    'tarih',    v_toh.tarih,
    'sperma',   v_toh.sperma,
    'hekim_id', v_toh.hekim_id
  );
  v_yeni_denemeler := v_toh.denemeler || jsonb_build_array(v_eski);

  -- Tohumlama kaydını güncelle
  UPDATE public.tohumlama
  SET tarih         = p_tarih,
      sperma        = p_sperma,
      hekim_id      = COALESCE(p_hekim_id, hekim_id),
      irk_bilgisi   = COALESCE(p_irk_bilgisi, irk_bilgisi),
      deneme_sayisi = deneme_sayisi + 1,
      denemeler     = v_yeni_denemeler
  WHERE id = v_toh.id;

  -- Mevcut gebelik kontrol görevlerini iptal et
  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false
    AND gorev_tipi IN ('TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL');

  -- Yeni görevler oluştur (yeni tarihten)
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh.id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh.id::text);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tekrar Aşım ' || (v_toh.deneme_sayisi + 1) || '. deneme — ' ||
      COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh.id,
    'deneme_sayisi', v_toh.deneme_sayisi + 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_tekrar_kaydet(text, date, text, text, text)
  TO anon, authenticated;
`})
```

**Doğrulama:**
```
supabase_query({
  table: "information_schema.routines",
  filters: "routine_name=eq.tohumlama_tekrar_kaydet",
  select: "routine_name,routine_type"
})
```
Beklenen: 1 satır dönmeli.

**Commit:**
```bash
git add supabase/migrations/20260522000004_tekrar_asim.sql
git commit -m "feat(db): tohumlama_tekrar_kaydet RPC — tekrar asim kayd+stok+gorev"
```

---

## Task 3 + Task 4 — Paralel Çalıştır

Task 3 (api.js) ve Task 4 (index.html modal) birbirinden bağımsız. `/skill:delegate` ile paralel aç.

---

### Task 3 — api.js: RPC kayıt

**Dosya sahipliği:** `js/api.js`

**Okuma:**
```bash
grep -n "tohumlama_kaydet\|RPC_TABLES\|case 'tohumlama" /root/egesut-erp1/js/api.js | head -10
grep -n "tohumlama_kaydet" /root/egesut-erp1/js/ui.js | head -5
```

**Uygulama — api.js'de iki yere ekle:**

1. `RPC_TABLES` objesine (tohumlama_kaydet'in hemen altına):
```js
tohumlama_tekrar_kaydet: ['tohumlama', 'gorev_log', 'stok_hareket'],
```

2. `buildRpcParams` switch/case içine (case 'tohumlama_kaydet' bloğunun hemen altına):
```js
case 'tohumlama_tekrar_kaydet':
  return {
    p_hayvan_id: data.hayvan_id,
    p_tarih:     data.tarih,
    p_sperma:    data.sperma,
    p_hekim_id:  data.hekim_id || null,
  };
```

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/api.js && echo "OK"
```

**Acceptance criteria:** api.js syntax hatasız, `tohumlama_tekrar_kaydet` RPC_TABLES'da ve buildRpcParams'da kayıtlı.

---

### Task 4 — index.html: Tekrar Aşım modali

**Dosya sahipliği:** `index.html`

**Okuma:**
```bash
sed -n '562,597p' /root/egesut-erp1/index.html
```
Mevcut `m-insem` modalini gör.

**Uygulama** — `m-insem` modalinin kapanış `</div>` satırından hemen sonra aşağıdaki modal bloğunu ekle:

```html
<!-- TEKRAR AŞIM MODALI -->
<div id="m-insem-tekrar" class="mo" data-action="mclose-overlay">
  <div class="modal"><div class="m-handle"></div><div class="m-title">🔁 Tekrar Aşım</div>
    <div class="m-body">
      <input type="hidden" id="tr-hid">
      <div class="fg"><label class="flbl">Küpe No</label>
        <div id="tr-kupe-label" class="fi" style="background:var(--card2);color:var(--ink2);cursor:default"></div>
      </div>
      <div class="fg"><label class="flbl">Tohumlama Tarihi *</label><input id="tr-tarih" class="fi" type="date"></div>
      <div class="fg"><label class="flbl">Sperma / Boğa Kodu *</label>
        <div style="display:flex;gap:6px;margin-bottom:6px">
          <button type="button" id="btn-tr-sperma-stok" data-action="tr-sperma-stok" style="flex:1;padding:7px;background:rgba(42,107,181,.1);border:1.5px solid var(--blue);border-radius:var(--r1);font-size:.75rem;font-weight:700;color:var(--blue);cursor:pointer">📦 Stoktan Seç</button>
          <button type="button" id="btn-tr-sperma-elle" data-action="tr-sperma-elle" style="flex:1;padding:7px;background:var(--card2);border:1px solid var(--card3);border-radius:var(--r1);font-size:.75rem;font-weight:700;color:var(--ink3);cursor:pointer">✏️ Elle Gir</button>
        </div>
        <div id="tr-sperma-stok-area">
          <select id="tr-sperma-select" class="fsel" data-change="tr-sperma-select">
            <option value="">Sperma seçin…</option>
          </select>
          <input type="hidden" id="tr-sperma" value="">
        </div>
        <div id="tr-sperma-elle-area" style="display:none">
          <input id="tr-sperma-text" class="fi" placeholder="Boğa kodu yazın…" autocomplete="off">
          <div id="ac-trsperma" class="ac-box" style="display:none"></div>
        </div>
        <div id="tr-sperma-hint" style="font-size:.7rem;color:var(--ink3);margin-top:4px"></div>
      </div>
      <div class="fg"><label class="flbl">Hekim</label><select id="tr-hekim" class="fsel"></select></div>
      <div style="font-size:.75rem;color:var(--amber);background:rgba(245,158,11,.08);border-radius:8px;padding:8px 10px;margin-bottom:8px">
        ⚠️ Mevcut tohumlama kaydı güncellenecek, görevler yeni tarihten hesaplanacak, stok düşülecek.
      </div>
      <button class="btn btn-g" data-action="submit-tekrar-asim">🔁 Tekrar Kaydet + Görevleri Güncelle</button>
      <button class="btn btn-o" data-action="close-tekrar-asim" style="margin-top:6px">İptal</button>
    </div>
  </div>
</div>
```

**Doğrulama:**
```bash
grep -c "m-insem-tekrar\|tr-hid\|tr-tarih\|tr-sperma" /root/egesut-erp1/index.html
```
Beklenen: 4+ satır.

**Acceptance criteria:** Modal HTML doğru, id'ler benzersiz, m-insem ile aynı sperma stok/elle toggle yapısına sahip.

---

Her iki task bitince dosyaları oku ve devam et.

---

## Task 5 — forms.js: submitTekrarAsim fonksiyonu

Task 3 ve 4 tamamlandıktan sonra başla.

**Okuma:**
```bash
sed -n '155,197p' /root/egesut-erp1/js/forms.js
```
`submitInsem` fonksiyonunu gör, aynı pattern'i takip et.

**Uygulama** — `submitInsem` fonksiyonunun hemen altına ekle:

```js
// ── TEKRAR AŞIM ───────────────────────────────
async function submitTekrarAsim(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid    = document.getElementById('tr-hid').value;
  const tarih  = document.getElementById('tr-tarih').value;
  const sperma = document.getElementById('tr-sperma').value;
  if (!hid || !tarih || !sperma) { toast('Tarih ve Sperma zorunlu', true); return; }
  if (tarih > new Date().toISOString().split('T')[0]) { toast('Tarih ileri olamaz', true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('tohumlama_tekrar_kaydet', {
      p_hayvan_id: hid,
      p_tarih:     tarih,
      p_sperma:    sperma,
      p_hekim_id:  document.getElementById('tr-hekim').value || null,
    });
    toast('✅ Tekrar aşım kaydedildi, görevler güncellendi');
    closeM('m-insem-tekrar');
    document.getElementById('tr-hid').value = '';
    document.getElementById('tr-sperma').value = '';
    pullTables(['tohumlama','gorev_log','hayvanlar']).then(() => {
      renderSafe();
      if (typeof loadUreme === 'function' && window._curUremeTab === 'tohumlama') {
        loadUreme('tohumlama');
      }
    }).catch(console.warn);
  } catch (e) {
    toast('❌ Tekrar aşım kaydedilemedi: ' + getUserMessage(e), true);
  } finally { if (btn) { btn.disabled = false; btn.textContent = '🔁 Tekrar Kaydet + Görevleri Güncelle'; } }
}
```

**Ayrıca** — `openTekrarAsim` fonksiyonu ekle (butona tıklayınca modal aç + küpe/hayvan_id doldur):

```js
function openTekrarAsim(hayvanId, kupeNo) {
  document.getElementById('tr-hid').value = hayvanId;
  document.getElementById('tr-kupe-label').textContent = kupeNo;
  document.getElementById('tr-tarih').value = new Date().toISOString().split('T')[0];
  document.getElementById('tr-sperma').value = '';
  document.getElementById('tr-sperma-select').value = '';
  // Hekim listesini doldur (aynı insem popup gibi)
  const hekimSel = document.getElementById('tr-hekim');
  const insemHekimSel = document.getElementById('i-hekim');
  if (insemHekimSel && hekimSel) hekimSel.innerHTML = insemHekimSel.innerHTML;
  openM('m-insem-tekrar');
}
```

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/forms.js && echo "OK"
```

**Commit:**
```bash
git add js/forms.js js/api.js index.html
git commit -m "feat(ui): tekrar asim modal + submitTekrarAsim + api.js kayit"
```

---

## Task 6 — ui.js: Badge + Buton + History (3 yer)

Bu task forms.js + api.js + index.html tamamlandıktan sonra.

**Okuma:**
```bash
# Hayvan kartı tohumlama history (badge için)
grep -n "hist-row.*openTohDet\|deneme_no\|hist-title" /root/egesut-erp1/js/ui.js | head -10
# Üreme sekmesi tohumlama listesi
sed -n '1517,1545p' /root/egesut-erp1/js/ui.js
# openDet fonksiyonu — tohumlama bölümü
grep -n "openDet\|gebeTohumlama\|openTohDet\|btn-g.*Doğum" /root/egesut-erp1/js/ui.js | head -15
# openTohDet fonksiyonu
sed -n '3075,3130p' /root/egesut-erp1/js/ui.js
```

**Değişiklik 1 — Hayvan kartı tohumlama satırı (line ~785)**

`deneme_no||1` ile `deneme_sayisi` arasında şu an fark var. Badge şartını düzelt:

Şu anki:
```js
<div class="hist-title">${t.sperma||'—'} · ${t.deneme_no||1}. deneme</div>
```

Sonrası (deneme_sayisi > 1 ise "N. deneme" badge ekle, 1 ise normal göster):
```js
<div class="hist-title">${t.sperma||'—'}${t.deneme_sayisi > 1 ? ` <span style="background:var(--amber);color:#fff;font-size:.65rem;padding:1px 5px;border-radius:8px;font-weight:700">${t.deneme_sayisi}. Deneme</span>` : ''}</div>
```

**Değişiklik 2 — openDet: Tekrar Aşım butonu**

`openDet` fonksiyonunda gebe hayvan için "Doğum Yaptı" butonunun olduğu bloğu bul. Hemen altına veya yanına şunu ekle:

Bekliyor tohumlama var ve ≤15 gün ise buton göster. `a` objesi `hayvan_durum_view`'dan geliyor, `toh_sonuc` ve `toh_gun` mevcut.

```js
if (a.toh_sonuc === 'Bekliyor' && a.toh_gun != null && a.toh_gun <= 15) {
  h += `<button class="btn" style="flex:1;padding:9px;font-weight:700;background:var(--amber);color:#fff;border:none" onclick="openTekrarAsim('${a.id}','${a.kupe_no||a.id}')">🔁 Tekrar Aşım</button>`;
}
```

**Değişiklik 3 — Üreme sekmesi `_uremeTohumlama` liste satırı (line ~1518)**

Şu anki liste satırında sadece kupe + sperma var. Deneme badge ekle:

```
sed -n '1525,1545p' /root/egesut-erp1/js/ui.js
```

`hist-title` satırına aynı badge pattern'i uygula. Ayrıca satırın altına — Bekliyor + ≤15 gün ise Tekrar butonu ekle:

```js
${t.sonuc === 'Bekliyor' && t.toh_gun != null && t.toh_gun <= 15
  ? `<button onclick="openTekrarAsim('${t.hayvan_id}','${kupe}')" style="margin-top:4px;font-size:.72rem;padding:4px 10px;background:var(--amber);color:#fff;border:none;border-radius:8px;cursor:pointer">🔁 Tekrar Aşım</button>`
  : ''}
```

Not: `_uremeTohumlama` listesi `idbGetAll('tohumlama')` + `getData('hayvanlar')` ile çalışır. `toh_gun` hesapla: `Math.floor((Date.now() - new Date(t.tarih)) / 86400000)`.

**Değişiklik 4 — openTohDet: denemeler history**

`openTohDet` (line ~3075) fonksiyonunda modal içeriği oluştururken, `toh.denemeler?.length > 0` ise önceki denemeler bölümü ekle:

```js
const denemelerHtml = (toh.denemeler && toh.denemeler.length > 0)
  ? `<div style="margin-top:12px;padding-top:10px;border-top:1px solid var(--card3)">
       <div style="font-size:.72rem;font-weight:700;color:var(--ink3);margin-bottom:6px">Önceki Denemeler</div>
       ${toh.denemeler.map(d => `
         <div style="display:flex;gap:8px;align-items:center;padding:4px 0;font-size:.78rem">
           <span style="background:var(--card2);border-radius:6px;padding:1px 6px;font-weight:700">${d.no}.</span>
           <span>${d.tarih||'?'}</span>
           <span style="color:var(--ink3)">· ${d.sperma||'?'}</span>
         </div>`).join('')}
     </div>`
  : '';
```

Bu `denemelerHtml`'i modal body'nin uygun yerine yerleştir.

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/ui.js && echo "OK"
```

**Commit:**
```bash
git add js/ui.js
git commit -m "feat(ui): tekrar asim badge + buton (hayvan karti + ureme sekmesi) + openTohDet history"
```

---

## Task 7 — ui.js: data-action handler'ları ekle

**Okuma:**
```bash
grep -n "data-action.*submit-insem\|data-action.*close-insem\|case 'submit-insem'\|case 'close-insem'" \
  /root/egesut-erp1/js/ui.js | head -10
```

`submit-insem` ve `close-insem` handler'larının bulunduğu yere aşağıdakileri ekle:

```js
case 'submit-tekrar-asim': submitTekrarAsim(e.target.closest('button')); break;
case 'close-tekrar-asim':  closeM('m-insem-tekrar'); break;
case 'tr-sperma-stok':
  document.getElementById('tr-sperma-stok-area').style.display = '';
  document.getElementById('tr-sperma-elle-area').style.display = 'none';
  break;
case 'tr-sperma-elle':
  document.getElementById('tr-sperma-stok-area').style.display = 'none';
  document.getElementById('tr-sperma-elle-area').style.display = '';
  break;
case 'tr-sperma-select':
  document.getElementById('tr-sperma').value =
    document.getElementById('tr-sperma-select').value;
  break;
```

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/ui.js && echo "OK"
```

**Commit:**
```bash
git add js/ui.js
git commit -m "feat(ui): tekrar asim data-action handler'lari"
```

---

## Task 8 — Push + Son Doğrulama

```bash
git push origin main
```

**DB doğrulama — kolon eklendi mi:**
```
supabase_query({
  table: "tohumlama",
  filters: "hayvan_id=eq.bac3b8f8-43c3-4cf5-83ed-6e1073c16fec",
  select: "id,tarih,sperma,deneme_sayisi,denemeler",
  limit: 1
})
```
Beklenen: `deneme_sayisi:1, denemeler:[]` görünmeli.

**RPC doğrulama — fonksiyon erişilebilir mi:**
```
supabase_rpc({function_name: "tohumlama_tekrar_kaydet", params: "{\"p_hayvan_id\":\"test\",\"p_tarih\":\"2026-01-01\",\"p_sperma\":\"X\"}"})
```
Beklenen: `'Hayvan bulunamadı: test'` hatası — fonksiyon var ve çalışıyor demek.

**Tamamlanma raporu:**
```
TAMAMLANDI

Task 1 — Schema + cycle trigger fix: ✅ [commit]
Task 2 — tohumlama_tekrar_kaydet RPC: ✅ [commit]
Task 3 — api.js: ✅ [commit]
Task 4 — index.html modal: ✅ [commit]
Task 5 — forms.js: ✅ [commit]
Task 6 — ui.js badge+buton+history: ✅ [commit]
Task 7 — data-action handlers: ✅ [commit]
Task 8 — Push: ✅

Açık soru: [varsa yaz]
```
