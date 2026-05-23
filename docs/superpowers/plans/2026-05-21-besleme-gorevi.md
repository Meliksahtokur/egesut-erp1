# Anyonik Besleme Görevi — Implementation Plan

> **For agentic workers:** Use `egesut-telsiz` recipe. DB değişikliği öncesi `approval_req` gönder, onay bekle.

**Goal:** 260+ günlük gebe hayvanlara sabah+akşam anyonik besleme görevi oluştur (doğuma kadar zincir); dashboard'da 260+ gün uyarı badge ekle.

**Architecture:** `gebelik_protokol_kontrol` RPC'ye 260. gün sabah+akşam çifti eklenir (günlük dedup). `besleme_tamam` RPC tamamlama + ertesi gün zincirleme yapar. Doğumda aktif BESLEME görevleri iptal edilir.

**Tech Stack:** PostgreSQL RPC, Supabase, vanilla JS (ui.js)

---

## Referans Okuma (başlamadan önce)

```bash
file_read("supabase/migrations/99999999999999_ground_truth.sql")   # canonical DB
file_read(".claude/rpc-reference.md")                               # RPC imzaları
file_read("supabase/migrations/20260521000001_gebelik_protokol_kontrol_hayvan_listesi.sql")  # extend edilecek RPC
```

---

## Dosya Haritası

| Dosya | Değişiklik |
|---|---|
| `supabase/migrations/20260521000005_besleme_gorevi.sql` | YENİ — 2 yeni RPC + dogum_kaydet entegrasyonu |
| `js/ui.js` | DEĞİŞİKLİK — dashboard badge (satır ~1452) + renderTask BESLEME butonu (satır ~430) + `beslemeGunTamam()` fonksiyonu |

---

## Task 1 — Migration: gebelik_protokol_kontrol güncelle + besleme_tamam RPC

**Files:**
- Create: `supabase/migrations/20260521000005_besleme_gorevi.sql`

### Mevcut `gebelik_protokol_kontrol` nerede değiştiriliyor

`gebelik_protokol_kontrol` içindeki LOOP'a, 265. gün bloğundan SONRA eklenecek:

```sql
-- ── 260. gün: Anyonik Besleme — SABAH (günlük zincir başlangıcı) ──────
IF v_gun >= 260 THEN
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
         '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = v_toh.hayvan_id
      AND gorev_tipi = 'BESLEME'
      AND aciklama = '🌅 Anyonik Besleme (Sabah)'
      AND hedef_tarih = CURRENT_DATE
      AND iptal = false
  );
  GET DIAGNOSTICS v_sayac = ROW_COUNT;
  v_olusturulan := v_olusturulan + v_sayac;

  -- ── 260. gün: Anyonik Besleme — AKŞAM ────────────────────────────
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
         '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, 'BESLEME_OTOMATIK'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = v_toh.hayvan_id
      AND gorev_tipi = 'BESLEME'
      AND aciklama = '🌙 Anyonik Besleme (Akşam)'
      AND hedef_tarih = CURRENT_DATE
      AND iptal = false
  );
  GET DIAGNOSTICS v_sayac = ROW_COUNT;
  v_olusturulan := v_olusturulan + v_sayac;
END IF;
```

**Önemli:** Diğer ILERI_GEBE görevleri `aciklama` ile deduplicate eder (tüm ömür boyunca bir kez).
BESLEME ise `hedef_tarih = CURRENT_DATE` ile deduplicate eder (her gün yeni çift).

### `besleme_tamam` RPC — tamamlama + zincirleme

```sql
CREATE OR REPLACE FUNCTION public.besleme_tamam(p_gorev_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev gorev_log%ROWTYPE;
  v_yeni_id uuid;
BEGIN
  -- 1. Görevi çek
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten kapalı');
  END IF;

  -- 2. Tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- 3. Hayvan hâlâ gebe mi kontrol et (doğum yapmışsa zinciri kesme)
  IF NOT EXISTS (
    SELECT 1 FROM tohumlama
    WHERE hayvan_id = v_gorev.hayvan_id
      AND sonuc = 'Gebe'
  ) THEN
    RETURN jsonb_build_object('ok', true, 'zincir', 'hayvan_artik_gebe_degil');
  END IF;

  -- 4. Zincirleme: ertesi gün için aynı besleme tipini oluştur
  v_yeni_id := gen_random_uuid();
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih,
                         tamamlandi, kaynak, parent_id)
  SELECT v_yeni_id, v_gorev.hayvan_id, 'BESLEME',
         v_gorev.aciklama,                 -- aynı başlık (Sabah veya Akşam)
         v_gorev.hedef_tarih + 1,          -- ertesi gün
         false, 'BESLEME_OTOMATIK', v_gorev.id::text
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = v_gorev.hayvan_id
      AND aciklama = v_gorev.aciklama
      AND hedef_tarih = v_gorev.hedef_tarih + 1
      AND iptal = false
  );

  RETURN jsonb_build_object('ok', true, 'yeni_gorev_id', v_yeni_id, 'tarih', v_gorev.hedef_tarih + 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.besleme_tamam(text) TO anon, authenticated;
```

### Doğumda aktif BESLEME görevleri iptal et

`dogum_kaydet` RPC içine eklenecek (veya yeni trigger). 
`dogum_kaydet`'i ground_truth'ta bul, `UPDATE gorev_log SET iptal=true` satırı varsa yanına ekle, yoksa aşağıdaki bloğu ekle:

```sql
-- Doğumda aktif BESLEME görevlerini iptal et
UPDATE gorev_log
SET iptal = true
WHERE hayvan_id = p_anne_id        -- dogum_kaydet'teki anne parametresi
  AND gorev_tipi = 'BESLEME'
  AND tamamlandi = false
  AND iptal = false;
```

> ⚠️ ONAY ZORUNLU: Bu migration'ı yazmadan önce approval_req gönder.
> Etkilenen tablolar: gorev_log (INSERT + UPDATE), gebelik_protokol_kontrol (REPLACE)
> Risk: Mevcut gebe hayvanlara bugün 2 görev oluşur — idempotent, güvenli

- [ ] **Step 1: ground_truth + rpc-reference oku**
- [ ] **Step 2: dogum_kaydet RPC'deki anne parametre adını bul**

```bash
grep -n "dogum_kaydet\|p_anne\|anne_id" supabase/migrations/99999999999999_ground_truth.sql | head -20
```

- [ ] **Step 3: Approval_req gönder**

```
agent_send(to="claude", from_="[worker_id]",
  message="ONAY GEREKLİ:\n1. gebelik_protokol_kontrol REPLACE — BESLEME bloğu ekleniyor\n2. besleme_tamam(text) yeni RPC\n3. dogum_kaydet — iptal bloğu\nEtkilenen: gorev_log\nRisk: yok (idempotent)\nSQL taslağı hazır",
  message_type="approval_req")
```

- [ ] **Step 4: Migration dosyasını yaz**

`supabase/migrations/20260521000005_besleme_gorevi.sql` — içerik:

```sql
-- Migration: Anyonik Besleme Görevi — sabah+akşam zinciri
-- Etkiler:
--   1. gebelik_protokol_kontrol REPLACE — 260. günde BESLEME çifti ekle
--   2. besleme_tamam(text) yeni RPC — tamamlama + zincirleme
--   3. dogum_kaydet — doğumda aktif BESLEME iptal
-- Geri alınabilir: DROP FUNCTION besleme_tamam(text); gebelik_protokol_kontrol önceki haline dön

BEGIN;

-- 1. gebelik_protokol_kontrol REPLACE (265. gün bloğundan sonra BESLEME bloğu eklendi)
CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
-- [TAM FONKSİYON BURAYA — mevcut kodu kopyala, BESLEME bloğunu ekle]
-- ÖNEMLI: Mevcut tüm blokları (210/240/261/260/265) koru, sadece BESLEME ekle
$$;

-- 2. besleme_tamam RPC
CREATE OR REPLACE FUNCTION public.besleme_tamam(p_gorev_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
-- [yukarıdaki tam kod]
$$;

GRANT EXECUTE ON FUNCTION public.besleme_tamam(text) TO anon, authenticated;

-- 3. dogum_kaydet güncelle — doğumda BESLEME iptal
-- [ground_truth'taki dogum_kaydet'i oku, BESLEME iptal satırını ekle, REPLACE yap]

COMMIT;
```

- [ ] **Step 5: Migration deploy et**

```
supabase_migrate(sql: "[migration dosyasının içeriği]")
```

- [ ] **Step 6: Doğrulama**

```
supabase_query(table: "gorev_log",
  filters: "gorev_tipi=eq.BESLEME",
  limit: 5)
```

260+ günlük gebe hayvan varsa görev oluşmuş olmalı. Yoksa `supabase_rpc(function_name: "gebelik_protokol_kontrol", params: "{}")` ile tetikle.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20260521000005_besleme_gorevi.sql
git commit -m "feat(db): anyonik besleme görevi — sabah+akşam zinciri, doğumda iptal"
```

---

## Task 2 — ui.js: Dashboard 260+ badge

**Files:**
- Modify: `js/ui.js` satır ~1452-1463 (yaklaşan doğumlar kart render)

Mevcut kod (satır 1457-1463):
```javascript
return `<div class="hist-row" onclick="openDet('${t.hayvan_id}')" style="cursor:pointer">
  <div class="hist-dot" style="background:${renk}"></div>
  <div class="hist-main">
    <div class="hist-title">${kupe} · ${t.sperma||'?'}</div>
    <div class="hist-sub">🐮 ${fmtTarih(t.tarih)} → Tahmini doğum: <b>${fmtTarih(dogumTahmin)}</b> · <span style="background:${bg};color:${renk};border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem">⏳ ${kalan} gun kaldi</span></div>
  </div>
</div>`;
```

Şu hale getir — `gun >= 260` için uyarı badge ekle:

```javascript
const beslemeUyari = gun >= 260
  ? `<span style="background:rgba(176,120,0,.15);color:#b07800;border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem;margin-left:4px">⚠️ Anyonik Besleme</span>`
  : '';
return `<div class="hist-row" onclick="openDet('${t.hayvan_id}')" style="cursor:pointer">
  <div class="hist-dot" style="background:${renk}"></div>
  <div class="hist-main">
    <div class="hist-title">${kupe} · ${t.sperma||'?'}${beslemeUyari}</div>
    <div class="hist-sub">🐮 ${fmtTarih(t.tarih)} → Tahmini doğum: <b>${fmtTarih(dogumTahmin)}</b> · <span style="background:${bg};color:${renk};border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem">⏳ ${kalan} gun kaldi</span></div>
  </div>
</div>`;
```

- [ ] **Step 1: Satır 1452 civarını oku, tam kodu doğrula**

```bash
Read("js/ui.js", offset=1448, limit=20)
```

- [ ] **Step 2: Edit uygula**

Sadece `beslemeUyari` const ekle ve `hist-title` satırını güncelle.

- [ ] **Step 3: node syntax check**

```bash
node --check js/ui.js
```

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): dashboard yaklaşan doğumlar 260+ gün anyonik besleme uyarısı"
```

---

## Task 3 — ui.js: renderTask BESLEME butonu + beslemeGunTamam()

**Files:**
- Modify: `js/ui.js` satır ~430 (renderTask) ve ~503 (doneTask'tan sonra)

### 3a — renderTask'ta BESLEME butonu

Mevcut satır ~430:
```javascript
${subs.length===0&&t.gorev_tipi!=='ILERI_GEBE_ASI'?`<button class="ck-btn" onclick="event.stopPropagation();doneTask('${t.id}','${t.hayvan_id||''}','${t.stok_id||''}',${+t.miktar||0},'${t.padok_hedef||''}',this)">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
</button>`:''}
```

Şu hale getir — BESLEME için ayrı buton:
```javascript
${subs.length===0&&t.gorev_tipi==='BESLEME'?`<button class="ck-btn" onclick="event.stopPropagation();beslemeGunTamam('${t.id}',this)" style="background:var(--amber)">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
</button>`:''}
${subs.length===0&&t.gorev_tipi!=='ILERI_GEBE_ASI'&&t.gorev_tipi!=='BESLEME'?`<button class="ck-btn" onclick="event.stopPropagation();doneTask('${t.id}','${t.hayvan_id||''}','${t.stok_id||''}',${+t.miktar||0},'${t.padok_hedef||''}',this)">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
</button>`:''}
```

### 3b — beslemeGunTamam() fonksiyonu (doneTask'tan hemen sonra ekle, satır ~504)

```javascript
async function beslemeGunTamam(id, btn) {
  btn.disabled = true;
  btn.innerHTML = '<div class="spin" style="width:14px;height:14px;border-width:2px"></div>';
  try {
    const r = await rpc('besleme_tamam', { p_gorev_id: id });
    if (!r?.ok) throw new Error(r?.mesaj || 'Hata');
    toast('✅ Besleme tamamlandı — yarın için görev oluşturuldu');
    const elT = document.getElementById('tc-' + id);
    if (elT) { elT.classList.add('done'); setTimeout(() => elT.remove(), 320); }
    updateTaskBadge();
    loadDash();
  } catch (e) {
    btn.disabled = false;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';
    toast(e.message, true);
  }
}
```

### 3c — renderTask pill rengi (opsiyonel — BESLEME görevleri turuncu gösterilsin)

`renderTask` içindeki pill satırı:
```javascript
<span class="pill ${t.gorev_tipi||'DIGER'}">${...}</span>
```
CSS'e `.pill.BESLEME { background: rgba(176,120,0,.15); color: #b07800; }` ekle (index.html veya inline stil).

- [ ] **Step 1: renderTask satırlarını oku (428-435)**

```bash
Read("js/ui.js", offset=428, limit=10)
```

- [ ] **Step 2: renderTask edit — BESLEME butonu**

- [ ] **Step 3: beslemeGunTamam() fonksiyon ekle (doneTask bitişinden sonra)**

- [ ] **Step 4: node syntax check**

```bash
node --check js/ui.js
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): BESLEME görevi tamamlama butonu + beslemeGunTamam RPC çağrısı"
```

---

## Task 4 — api.js: besleme_tamam RPC_TABLES kaydı

**Files:**
- Modify: `js/api.js`

`RPC_TABLES` içine ekle (gebelik_protokol_kontrol satırının yanına):

```javascript
besleme_tamam:               ['gorev_log'],
```

Bu sayede `besleme_tamam` çağrısı sonrası `gorev_log` IDB otomatik refresh olur.

- [ ] **Step 1: api.js'de RPC_TABLES'ı bul**

```bash
grep -n "RPC_TABLES\|gebelik_protokol" js/api.js | head -10
```

- [ ] **Step 2: Edit**

- [ ] **Step 3: Commit**

```bash
git add js/api.js
git commit -m "feat(api): besleme_tamam RPC_TABLES kaydı — IDB auto-refresh"
```

---

## Task 5 — Push + Doğrulama

- [ ] **Step 1: Commit lock al + push**

```bash
curl -s -X POST http://localhost:8743/commit-lock/acquire \
  -H "Content-Type: application/json" -d '{"session_id":"WORKER_ID"}'
git push origin main
curl -s -X POST http://localhost:8743/commit-lock/release \
  -H "Content-Type: application/json" -d '{"session_id":"WORKER_ID"}'
```

- [ ] **Step 2: RPC tetikle + doğrula**

```
supabase_rpc(function_name: "gebelik_protokol_kontrol", params: "{}")
```

```
supabase_query(table: "gorev_log",
  filters: "gorev_tipi=eq.BESLEME&tamamlandi=eq.false",
  order: "hedef_tarih.desc",
  limit: 10)
```

260+ gebe hayvan varsa → sabah+akşam çifti görünmeli.

- [ ] **Step 3: Sonucu claude'a bildir**

```
agent_send(to="claude", from_="WORKER_ID",
  message="TAMAMLANDI: [commit hash] — anyonik besleme görevi\nDB: [X] hayvan için [Y] görev oluştu\nDashboard badge: ✅\nbeslemeGunTamam: ✅",
  message_type="result")
```

---

## Özet Kontrol

| Gereksinim | Task | Dosya |
|---|---|---|
| 260+ gün uyarı badge (dashboard) | Task 2 | ui.js:1452 |
| Sabah+akşam görev oluşturma | Task 1 | migration |
| Doğumda görevler iptal | Task 1 | dogum_kaydet RPC |
| Tamamlama → ertesi gün zincir | Task 1 + Task 3 | RPC + ui.js |
| IDB refresh | Task 4 | api.js |
| Görev listesinde BESLEME butonu | Task 3 | ui.js:430 |
