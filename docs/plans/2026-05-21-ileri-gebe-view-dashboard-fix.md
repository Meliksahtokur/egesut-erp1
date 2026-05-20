# [✅ TAMAMLANDI] İleri Gebeler Dashboard Tablosu — Düzeltme Planı

> **✅ TAMAMLANDI** — Dashboard ileri gebeler tablosu çalışıyor. RPC `hayvanlar` listesi döndürüyor (15 hayvan).
> Commits: `037b2f0` (RPC hayvan listesi + frontend view kaldır), `aea2be9` (startup RPC loadDash tetikleme fix)
> Migration: 20260521000001, 20260521000002

**Goal:** Dashboard'daki "İleri Gebeler (210+ gün)" bandının tekrar çalışmasını sağlamak.

**Architecture:** `93e830b` refactor'ünde ileri gebe hesaplaması frontend'den (tohumlama verisi üzerinden JS hesaplama) backend view'a (`ileri_gebe_view`) taşındı. View'da `id` kolonu olmadığı için IndexedDB store (`keyPath: 'id'`) row'ları kaydedemiyor. Aynı commit'te `gebelik_protokol_kontrol` RPC'si de oluşturuldu — bu RPC zaten 210+ günlük hayvanları sorguluyor.

**Çözüm:** RPC'nin döndürdüğü JSON'a gebe listesini ekle, frontend view yerine RPC sonucunu kullansın. Böylece ayrı bir view gereksiz hale gelir, IDB keyPath sorunu tamamen atlatılır.

**Tech Stack:** PostgreSQL (Supabase RPC), Vanilla JS (api.js/ui.js)

---

### Önceki Hatalı Analiz — Neden Yanlıştı

İlk planda `ileri_gebe_view`'a `t.hayvan_id AS id` ekleyerek çözmeyi önerdim. Bu çalışır ama **yanlış yaklaşım**:

1. Zaten çalışan bir RPC (`gebelik_protokol_kontrol`) var — aynı veriyi sorguluyor
2. Ayrı bir view + IDB store beslemesi gereksiz complexity
3. RPC sonucu doğrudan JS'e döner, IDB keyPath sorunu olmaz
4. "İş mantığı DB'de" prensibine de uygun — RPC zaten DB'de

---

### Task 1: RPC Dönüşüne Gebe Listesini Ekle

**TDD scenario:** New feature — mevcut RPC'ye ek dönüş alanı

**Files:**
- Modify: `supabase/migrations/20260519000001_gebelik_protokol_birlestirme.sql:14-135` (RPC tanımı)
  - Not: Bu migration deploy edildiyse yeni bir migration dosyası (`20260521000001`) oluşturulur
- Read: js/ui.js:138-145 (ileriGebeKontrol — RPC çağrısı)

**Step 1: RPC dönüşüne liste ekle**

Mevcut RPC dönüşü:
```sql
RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
```

Yeni dönüş:
```sql
RETURN jsonb_build_object(
  'ok', true,
  'olusturulan', v_olusturulan,
  'hayvanlar', (
    SELECT jsonb_agg(
      jsonb_build_object(
        'hayvan_id',    t.hayvan_id,
        'tarih',        t.tarih::text,
        'gebelik_gun',  CURRENT_DATE - t.tarih::date,
        'kupe_no',      h.kupe_no,
        'devlet_kupe',  h.devlet_kupe,
        'grup',         h.grup,
        'padok',        h.padok
      )
      ORDER BY CURRENT_DATE - t.tarih::date DESC
    )
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id
    WHERE t.sonuc = 'Gebe'
      AND h.durum = 'Aktif'
      AND CURRENT_DATE - t.tarih::date >= 210
      AND t.tarih = (
        SELECT MAX(t2.tarih) FROM tohumlama t2
        WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
      )
  )
);
```

Not: Bu alt sorgu, RPC'nin zaten döngüde kullandığı veriyle aynı — RPC içinde ayrıca `DISTINCT ON (t.hayvan_id)` ile dolaşılan listeye uygun.

Eski migration deploy edilmişse **yeni migration**:
`supabase/migrations/20260521000001_gebelik_protokol_kontrol_hayvan_listesi.sql`
```sql
BEGIN;
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
  v_stok_id     text;
BEGIN
  -- ... (tüm mevcut gövde aynen kalır) ...

  RETURN jsonb_build_object(
    'ok', true,
    'olusturulan', v_olusturulan,
    'hayvanlar', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'hayvan_id',    t.hayvan_id,
          'tarih',        t.tarih::text,
          'gebelik_gun',  CURRENT_DATE - t.tarih::date,
          'kupe_no',      h.kupe_no,
          'devlet_kupe',  h.devlet_kupe,
          'grup',         h.grup,
          'padok',        h.padok
        )
        ORDER BY CURRENT_DATE - t.tarih::date DESC
      )
      FROM tohumlama t
      JOIN hayvanlar h ON h.id = t.hayvan_id
      WHERE t.sonuc = 'Gebe'
        AND h.durum = 'Aktif'
        AND CURRENT_DATE - t.tarih::date >= 210
        AND t.tarih = (
          SELECT MAX(t2.tarih) FROM tohumlama t2
          WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
        )
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.gebelik_protokol_kontrol() TO anon, authenticated;
COMMIT;
```

**Step 2: Deploy**

```bash
# GitHub Actions → main push
# veya Supabase Dashboard SQL Editor ile manuel
git add supabase/migrations/20260521000001_gebelik_protokol_kontrol_hayvan_listesi.sql
git commit -m "feat(db): gebelik_protokol_kontrol hayvan listesi döndürsün"
git push origin main
```

---

### Task 2: Frontend — View yerine RPC Sonucunu Kullan

**TDD scenario:** Modifying tested code — `loadDash` değişecek, mevcut render koduna dokunulmayacak

**Files:**
- Modify: `js/ui.js:200-260` (loadDash — ileri_gebe_view yüklemesini kaldır)
- Modify: `js/ui.js:138-145` (ileriGebeKontrol — dönen listeyi state'e kaydet)

**Step 1: `ileriGebeKontrol` — RPC dönüşündeki hayvanları global state'e yaz**

```js
async function ileriGebeKontrol(){
  try {
    const res=await rpc('gebelik_protokol_kontrol');
    if(res?.ok){
      const n=res.olusturulan||0;
      toast(n>0?`✅ ${n} yeni görev oluşturuldu`:'✅ Tüm görevler güncel');
      // Gelen hayvan listesini global'e kaydet, dashboard kullansın
      if(res.hayvanlar) {
        window.__ileriGebeListesi = res.hayvanlar;
        loadDash();
      }
      if(n>0) pullTables(['gorev_log']).then(loadDash).catch(console.warn);
    }
  } catch(e){ toast('❌ '+e.message,true); }
}
```

**Step 2: `loadDash` — view'ı kaldır, global state'ten oku**

```js
async function loadDash(){
  const el=document.getElementById('dash-body');
  try {
    const today=new Date().toISOString().split('T')[0];
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
      // ← ileri_gebe_view kaldırıldı
    ]);
    // ...
    const ileriGebeler = window.__ileriGebeListesi || [];
    // ...
```

**Step 3: Başlangıçta RPC'yi çağır (app.js'de zaten var)**

```js
// app.js:625 — zaten çağrılıyor, sadece yönlendir
rpc('gebelik_protokol_kontrol').then(res => {
  if(res?.hayvanlar) window.__ileriGebeListesi = res.hayvanlar;
}).catch(console.warn);
```

Bu zaten `app.js:625`'te var, sadece sonucu `window.__ileriGebeListesi`'ne yazması gerekiyor.

**Step 4: TABLES listesinden `ileri_gebe_view`'ı kaldır**

```js
// api.js:10-13
const TABLES = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
  'vaccination_log','padoklar','grup_padok_eslem','hekimler'/*, 'ileri_gebe_view' */];
```

Böylece `ileri_gebe_view` için IDB store yaratılmaz, `pullTables` çağrılmaz.

**Step 5: FETCHERS listesinden kaldır**

```js
// api.js:351
// ileri_gebe_view: () => db.from('ileri_gebe_view').select('*'),
```

---

### Task 3: İsteğe Bağlı — View'ı DB'den Kaldır

View Supabase'de gereksiz yere duruyor olacak. Temizlik için:

**Step 3a (opsiyonel): Yeni migration**

```sql
BEGIN;
DROP VIEW IF EXISTS public.ileri_gebe_view;
COMMIT;
```

Temizlik migration'ı: `supabase/migrations/20260521000002_drop_ileri_gebe_view.sql`

Not: Bu adım isteğe bağlı — view'ın durması bir zarar vermez.

---

### Task 4: Commit

```bash
git add supabase/migrations/20260521000001_gebelik_protokol_kontrol_hayvan_listesi.sql
git add js/ui.js
git add js/api.js
git commit -m "fix: ileri gebe dashboard — RPC sonucu kullan, view kaldirildi"
git push origin main
```

---

## Neden Bu Yaklaşım Daha İyi

| Kriter | View yaklaşımı | RPC yaklaşımı |
|--------|---------------|---------------|
| IDB keyPath sorunu | Var (view'da `id` yok) | Yok (RPC sonucu doğrudan JS) |
| İş mantığı yeri | DB'de | DB'de (RPC) |
| Ek complexity | View + IDB store + REST fetch | Tek RPC çağrısı |
| Veri güncelliği | pullTables ile ayrı fetch | RPC her çağrıldığında taze |
| Migration sayısı | Yeni migration gerekli | RPC REPLACE (mevcut migration güncellenebilir) |
| Mimari uyum | "Frontend sadece render" prensibi | "Tüm iş mantığı RPC'de" prensibi |

## Risk Değerlendirmesi

| Risk | Olasılık | Etki | Mitigasyon |
|------|----------|------|-----------|
| RPC dönüşü büyür, payload ağırlaşır | Düşük | Hafif network gecikmesi | Liste sadece 210+ gün hayvanlar (genelde <10-20 kayıt) |
| `window.__ileriGebeListesi` stale kalır | Orta | Dashboard güncel olmaz | `ileriGebeKontrol` butonu ve app.js init çağrısı yeniler |
| Eski view deploy edilmiş, kaldırılmazsa sorun olmaz | Yok | View durur, kullanılmaz | View'ı bırakmak güvenli |
