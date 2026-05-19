# Gebelik Protokol Birleştirme — Implementasyon Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ileri_gebe_gorev_kontrol()` ve `laktasyon_kuru_kontrol()` kaldırılıp tek `gebelik_protokol_kontrol()` RPC'sine birleştirilecek; `ileri_gebe_view` VIEW oluşturulup dashboard bu view'dan beslenecek, frontend'deki hesap kodu kaldırılacak.

**Architecture:** Tek bir RPC (`gebelik_protokol_kontrol`) tüm gebe inekler için `tohumlama.tarih` referansıyla tüm milestone görevlerini açar (210-kuru, 240-aşı1, 261-aşı2-düve, 260-Ademin, 265-Evit). Ayrı bir VIEW (`ileri_gebe_view`) 210+ günlük gebe inekleri döndürür; dashboard bu view'ı IDB'den okur, frontend'de hesap yapılmaz.

**Tech Stack:** PostgreSQL RPC (SECURITY DEFINER), Supabase REST/IDB, Vanilla JS

**ÖN ONAY DURUMU:** Bu görev Claude Orkestratör tarafından önceden onaylanmıştır. Ek approval_req göndermeye gerek yoktur.

---

## Dosya Haritası

| Dosya | Değişiklik |
|-------|------------|
| `supabase/migrations/20260519000001_gebelik_protokol_birlestirme.sql` | YENİ — DROP eski 2 RPC, CREATE gebelik_protokol_kontrol, CREATE ileri_gebe_view |
| `js/api.js` | MODIFY — TABLES + fetcher'a ileri_gebe_view ekle, RPC_TABLES'a gebelik_protokol_kontrol ekle |
| `js/ui.js` | MODIFY — ileriGebeKontrol() RPC adı, loadDash Promise.all + ileriGebeler hesabı, _dashBands render |
| `js/app.js` | MODIFY — satır 651 RPC adı |

---

## Task 1: Migration Dosyasını Yaz ve Deploy Et

**Files:**
- Create: `supabase/migrations/20260519000001_gebelik_protokol_birlestirme.sql`

### Ön kontrol — ground_truth.sql oku

- [ ] **Adım 1: Canonical referansı oku**

```bash
file_read("/root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql")
```

Doğrula: `gorev_log.id` TEXT (uuid string saklar), `padoklar.id` UUID, `padok_hedef` kolonu `gorev_log`'da var.

- [ ] **Adım 2: Mevcut RPC imzalarını oku**

```bash
file_read("/root/egesut-erp1/.claude/rpc-reference.md")
```

`ileri_gebe_gorev_kontrol` ve `laktasyon_kuru_kontrol` imzalarını teyit et.

### Migration dosyasını oluştur

- [ ] **Adım 3: Migration dosyasını yaz**

`/root/egesut-erp1/supabase/migrations/20260519000001_gebelik_protokol_birlestirme.sql` içeriği:

```sql
-- ============================================================
-- gebelik_protokol_birlestirme
-- ileri_gebe_gorev_kontrol + laktasyon_kuru_kontrol → gebelik_protokol_kontrol
-- ileri_gebe_view: dashboard için backend taraflı 210+ gün hesabı
-- ============================================================

-- 1. Eski fonksiyonları kaldır
DROP FUNCTION IF EXISTS public.ileri_gebe_gorev_kontrol();
DROP FUNCTION IF EXISTS public.laktasyon_kuru_kontrol();

-- 2. Birleşik RPC
CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_padok_kuru  text;
BEGIN
  -- Kuru/Gebe padok adını bul (yoksa NULL kalır, görev açılır ama padok_hedef boş olur)
  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  -- Tüm aktif gebe inekler — her hayvanın en son Gebe tohumlaması
  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- ── 210. gün: Kuru dönem transfer ──────────────────────────────
    -- Sadece hâlâ Sağmal grubunda olan ineklere (Kuru'ya taşınmamışsa)
    IF v_gun >= 210
       AND v_hayvan.grup ILIKE '%Sağmal%'
       AND v_hayvan.grup NOT ILIKE '%Kuru%'
    THEN
      v_hedef := v_toh.tarih::date + 210;
      INSERT INTO gorev_log (
        id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef
      )
      SELECT
        gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
        '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
        v_hedef, false, v_padok_kuru
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'PADOK_DEGISIM'
          AND aciklama ILIKE '%Kuru döneme%'
          AND iptal = false
          AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 240. gün: Rota-Corona 1. doz (tüm gebeler) ─────────────────
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 261. gün: Rota-Corona 2. doz (sadece düveler) ──────────────
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 260. gün: SC Ademin (tüm gebeler) ──────────────────────────
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 265. gün: IM E Vitamini (tüm gebeler) ──────────────────────
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.gebelik_protokol_kontrol() TO anon, authenticated;

-- 3. ileri_gebe_view — dashboard için 210+ günlük gebe inekler
CREATE OR REPLACE VIEW public.ileri_gebe_view AS
SELECT
  t.hayvan_id,
  t.tarih,                                         -- nearBirth hesabı için uyumluluk
  t.tarih AS tohumlama_tarihi,
  (CURRENT_DATE - t.tarih::date)::int AS gebelik_gun,
  h.kupe_no,
  h.devlet_kupe,
  h.grup,
  h.padok
FROM tohumlama t
JOIN hayvanlar h ON h.id = t.hayvan_id
WHERE t.sonuc = 'Gebe'
  AND h.durum = 'Aktif'
  AND CURRENT_DATE - t.tarih::date >= 210
  AND t.tarih = (
    SELECT MAX(t2.tarih)
    FROM tohumlama t2
    WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
  )
ORDER BY gebelik_gun DESC;

GRANT SELECT ON public.ileri_gebe_view TO anon, authenticated;
```

- [ ] **Adım 4: Migration'ı deploy et**

```
supabase_migrate(sql: "<yukarıdaki SQL içeriği>")
```

- [ ] **Adım 5: Doğrula — yeni RPC çalışıyor mu**

```sql
SELECT gebelik_protokol_kontrol();
```

Beklenen: `{"ok": true, "olusturulan": N}` — hata yok.

```sql
SELECT * FROM ileri_gebe_view LIMIT 5;
```

Beklenen: 210+ günlük gebe inekler, kupe_no, gebelik_gun kolonları dolu.

- [ ] **Adım 6: Commit**

```bash
cd /root/egesut-erp1
git add supabase/migrations/20260519000001_gebelik_protokol_birlestirme.sql
git commit -m "feat(db): gebelik_protokol_kontrol + ileri_gebe_view — ileri_gebe_gorev_kontrol ve laktasyon_kuru_kontrol birlestirildi"
```

---

## Task 2: api.js — İleri Gebe View Ekle

**Files:**
- Modify: `js/api.js`

- [ ] **Adım 1: TABLES array'ine ekle**

`api.js` satır 10-13 — `TABLES` array'ini bul:

```js
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler'];
```

Şu hale getir (`ileri_gebe_view` ekle):

```js
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler','ileri_gebe_view'];
```

- [ ] **Adım 2: Fetcher ekle**

`api.js` içinde `gebelik_ozet:` satırının hemen altına ekle:

```js
      gebelik_ozet:     () => db.from('gebelik_ozet_view').select('*'),
      ileri_gebe_view:  () => db.from('ileri_gebe_view').select('*'),
```

- [ ] **Adım 3: RPC_TABLES'a gebelik_protokol_kontrol ekle**

`RPC_TABLES` içindeki son satırdan önce ekle:

```js
  gebelik_protokol_kontrol:   ['gorev_log'],
```

- [ ] **Adım 4: DB_VER'i artır**

```js
const DB_VER  = 15;
```
→
```js
const DB_VER  = 16;
```

DB_VER artırılınca IDB otomatik silinip yeniden çekilir — `ileri_gebe_view` IDB'ye dahil olur.

- [ ] **Adım 5: Commit**

```bash
git add js/api.js
git commit -m "feat(api): ileri_gebe_view IDB cache + gebelik_protokol_kontrol RPC_TABLES"
```

---

## Task 3: ui.js — Dashboard Güncellemesi

**Files:**
- Modify: `js/ui.js`

Üç ayrı değişiklik yapılacak: (1) `ileriGebeKontrol` fonksiyonu, (2) `loadDash` içi, (3) `_dashBands` render.

### Değişiklik A — ileriGebeKontrol fonksiyonu (satır ~138-145)

- [ ] **Adım 1: RPC adını güncelle**

Bul:
```js
async function ileriGebeKontrol(){
  try {
    const res=await rpc('ileri_gebe_gorev_kontrol');
```

Değiştir:
```js
async function ileriGebeKontrol(){
  try {
    const res=await rpc('gebelik_protokol_kontrol');
```

### Değişiklik B — loadDash Promise.all (satır ~206-262)

- [ ] **Adım 2: Promise.all'a ileri_gebe_view ekle**

Bul:
```js
    const [animals,diseases,tasks,stock,births60,births90,gebeTohs,vaxLogs,vaccines,allKizginlik,allTohum]=await Promise.all([
      getData('hayvanlar',a=>a.durum==='Aktif'),
      getData('cases',c=>c.status==='active'),
      getData('gorev_log',t=>!t.tamamlandi&&!t.iptal),
      idbGetAll('stok'),
      getData('dogum',b=>b.tarih>=dAgo(63)&&b.tarih<=dAgo(58)),
      getData('dogum',b=>b.tarih>=dAgo(150)&&b.tarih<dAgo(89)),
      getData('tohumlama',t=>t.sonuc==='Gebe'),
      getData('vaccination_log'),
      getData('vaccines'),
      getData('kizginlik_log'),
      getData('tohumlama'),
    ]);
```

Değiştir (`ileriGebeView` eklendi):
```js
    const [animals,diseases,tasks,stock,births60,births90,gebeTohs,vaxLogs,vaccines,allKizginlik,allTohum,ileriGebeView]=await Promise.all([
      getData('hayvanlar',a=>a.durum==='Aktif'),
      getData('cases',c=>c.status==='active'),
      getData('gorev_log',t=>!t.tamamlandi&&!t.iptal),
      idbGetAll('stok'),
      getData('dogum',b=>b.tarih>=dAgo(63)&&b.tarih<=dAgo(58)),
      getData('dogum',b=>b.tarih>=dAgo(150)&&b.tarih<dAgo(89)),
      getData('tohumlama',t=>t.sonuc==='Gebe'),
      getData('vaccination_log'),
      getData('vaccines'),
      getData('kizginlik_log'),
      getData('tohumlama'),
      idbGetAll('ileri_gebe_view'),
    ]);
```

- [ ] **Adım 3: Frontend ileriGebeler hesabını kaldır, view'dan al**

Bul (satır ~235-238):
```js
    const ileriGebeler=gebeTohs
      .map(t=>({...t,gun:Math.floor((Date.now()-new Date(t.tarih))/86400000)}))
      .filter(t=>t.gun>=210)
      .sort((a,b)=>b.gun-a.gun);
```

Değiştir:
```js
    const ileriGebeler=ileriGebeView||[];
```

- [ ] **Adım 4: laktasyon_kuru_kontrol çağrısını kaldır**

Bul (satır ~258-261):
```js
    try {
      const resLak=await rpc('laktasyon_kuru_kontrol');
      if(resLak&&resLak.ok&&resLak.olusturulan>0) toast('⚠️ '+resLak.olusturulan+' inek kuru döneme geçirilmeli');
    } catch(e){ /* sessiz */ }
```

**Tamamen kaldır** — `gebelik_protokol_kontrol` app.js init'te çalışıyor, burada ayrıca çağırmaya gerek yok.

### Değişiklik C — _dashBands ileriGebeler render (satır ~179-185)

- [ ] **Adım 5: Render kodunu view'a göre güncelle**

Bul:
```js
      (ileriGebeler||[]).map(b=>{
        const a=aMap&&aMap[b.hayvan_id];
        const kid=a?.kupe_no||a?.devlet_kupe||b.hayvan_id;
        const gun=Math.floor((Date.now()-new Date(b.tarih))/86400000);
        return `<div class="arow" onclick="openDet('${b.hayvan_id}')"><div class="arow-left"><div class="arow-id">${kid}</div><div class="arow-sub">${gun}. gün · ${a?.grup||''}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
      }).join(''));
```

Değiştir (view doğrudan kupe_no, gebelik_gun, grup döndürüyor):
```js
      (ileriGebeler||[]).map(b=>{
        const kid=b.kupe_no||b.devlet_kupe||b.hayvan_id;
        return `<div class="arow" onclick="openDet('${b.hayvan_id}')"><div class="arow-left"><div class="arow-id">${kid}</div><div class="arow-sub">${b.gebelik_gun}. gün · ${b.grup||''}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
      }).join(''));
```

- [ ] **Adım 6: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): ileri_gebe_view IDB'den oku, frontend hesap kaldırıldı, gebelik_protokol_kontrol"
```

---

## Task 4: app.js — RPC Adı Güncelle

**Files:**
- Modify: `js/app.js`

- [ ] **Adım 1: satır 651'deki RPC adını güncelle**

Bul:
```js
      rpc('ileri_gebe_gorev_kontrol').catch(console.warn);
```

Değiştir:
```js
      rpc('gebelik_protokol_kontrol').catch(console.warn);
```

- [ ] **Adım 2: Commit**

```bash
git add js/app.js
git commit -m "feat(app): gebelik_protokol_kontrol — app init RPC adı güncellendi"
```

---

## Task 5: Push ve Doğrulama

- [ ] **Adım 1: Push**

```bash
cd /root/egesut-erp1
git push origin main
```

- [ ] **Adım 2: Fonksiyonel doğrulama — DB tarafı**

```sql
-- Yeni RPC çalışıyor mu?
SELECT gebelik_protokol_kontrol();
-- Beklenen: {"ok": true, "olusturulan": N}

-- View 210+ günlük gebe inekleri getiriyor mu?
SELECT kupe_no, gebelik_gun, grup FROM ileri_gebe_view ORDER BY gebelik_gun DESC;
-- Beklenen: 117 dahil dogum kaydı olmayan inekler de görünüyor

-- Eski fonksiyonlar gerçekten silindi mi?
SELECT proname FROM pg_proc WHERE proname IN ('ileri_gebe_gorev_kontrol','laktasyon_kuru_kontrol');
-- Beklenen: 0 satır
```

- [ ] **Adım 3: 117 numaralı hayvanı doğrula**

```sql
SELECT kupe_no, gebelik_gun FROM ileri_gebe_view WHERE kupe_no = '117';
-- Beklenen: 1 satır, gebelik_gun ~ 210
```

- [ ] **Adım 4: task_complete çağır**

---

## Önemli Notlar

### gorev_log.id Tipi
`gorev_log.id` **TEXT**'tir (uuid string saklar). INSERT için `gen_random_uuid()` kullan — `::text` cast yapma. WHERE karşılaştırmasında cast gerekmez.

### Kuru Dönem Dedup Mantığı
Kuru dönem görevi açılmadan önce şu kontrol yapılır:
- `gorev_tipi = 'PADOK_DEGISIM'`
- `aciklama ILIKE '%Kuru döneme%'`
- `iptal = false`
- `(NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')`

Bu sayede zaten tamamlanmış ama 24 saatten eski görevler için yeniden açılabilir.

### ileri_gebe_view ↔ nearBirth Uyumu
`ileri_gebe_view`'da `tarih` kolonu bulunur — bu `nearBirth` hesabı için `gebeTohs` ile uyumlu formattadır. `nearBirth` hesabı (`gebeTohs.filter(...)`) değişmeden kalır, sadece `ileriGebeler` değişir.

### Eski Görevler Etkilenmez
Migration sadece yeni RPC yazar + eski RPC'leri DROP eder. Mevcut `gorev_log` satırlarına dokunmaz.
