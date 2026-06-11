# BUG-059 Faz 0 Bulguları — Spec ↔ Ground Truth ↔ Live DB Drift Analizi

> **Tarih:** 2026-06-11
> **Amaç:** Spec'te yazılan ile ground truth (canonical referans) ve canlı DB (Supabase) arasındaki farkları (drift) tespit etmek. Bu, Pato 12 — Geçmiş BUG'ların kök nedeni.
> **Sonraki adım:** Spec revizyonu + Plan revizyonu (Faz 1-2 değişecek)
> **Okuma:** Implementation plan, handoff dosyası ile birlikte okunmalı

---

## Bulgular Özeti (5 Kritik + 7 Yüksek + 5 Orta + 4 Düşük = 21 Bulgu)

| # | Seviye | Bulgu | Spec'te | Gerçek (ground truth / live DB) |
|---|---|---|---|---|
| **B1** | 🔴 KRİTİK | `treatment_day_tamamla` parametre imzası | `(p_day_id, p_not)` yazdık | `(p_day_id, p_not, p_uygulanmadi_ids uuid[] DEFAULT '{}')` — 3 parametre, **p_uygulanmadi_ids'i unuttuk** |
| **B2** | 🔴 KRİTİK | `add_treatment_day` parametre imzası | `(p_case_id, p_date, p_sessions, p_existing_day_id)` yazdık | Canlıda sadece `(p_case_id, p_date)` — `p_planned_time` canlıda YOK (drift) |
| **B3** | 🔴 KRİTİK | Stok düşümü `add_treatment_day_with_sessions` içinde yazdık | "Yeni: atomik stok INSERT" | `add_drug_administration` ZATEN `INSERT INTO stok_hareket` yapıyor (notlar='drug_admin:'||v_id) |
| **B4** | 🔴 KRİTİK | `add_treatment_day_with_sessions` RPC'si "yeni" dedik | "Yeni RPC: tek gün + N seans ekle" | Mevcut: `add_treatment_day(p_day)` + N kez `add_drug_administration(p_day, ...)` — tek transaction gereksiz, 2 RPC yeterli |
| **B5** | 🔴 KRİTİK | Spec review'larında "p_uygulanmadi_ids" fark edilmedi | Self-review bile eklemedi | Ground truth L3340'ta açıkça var, 3 review turu atladi |
| **B6** | 🟠 YÜKSEK | `treatment_days.planned_time` drift | "Yeni kolon eklenecek" | Ground truth'ta var (L2933: `ADD COLUMN IF NOT EXISTS planned_time TIME`) ama canlıda HİÇ SET EDİLMEMİŞ (5 aktif vakada 13 gün, hepsi NULL) |
| **B7** | 🟠 YÜKSEK | `treatment_day_uygulamalar` tablosu | "Yeni tablo oluştur" | Yok (doğru) — ama `seans_sayisi` kolonu da yok (doğru) |
| **B8** | 🟠 YÜKSEK | `cases.animal_id` tipi | text varsaydık | Canlıda **2 farklı tip** var: UUID formatında (`1433f5f2-b60a-...`) + text format (`H000142`) — Pato 12'nin K1 benzeri yeni drift kaynağı |
| **B9** | 🟠 YÜKSEK | `treatment_day_uygulamalar.stok_hareket_ref` FK | "text REFERENCES stok_hareket(id)" | `stok_hareket.id` = **text** (doğrulandı) — FK uyumlu ✅ |
| **B10** | 🟠 YÜKSEK | Mevcut aktif vaka sayısı | 4 vaka (plan: 140, 5, 7, 9) | **5 vaka**: `eb10376a, a09f0d0b, 1db49a4e, 57bfc92c, c4ff42d9` (5. vaka yeni eklenmiş olmalı) |
| **B11** | 🟠 YÜKSEK | Mevcut tedavi gün sayısı | 4 vakada bilinmiyor | **13 gün, 3 tamamlanmış, 10 devam** + 10+ drug_admins + 10+ gorev_log |
| **B12** | 🟠 YÜKSEK | `treatment_day_not_guncelle`, `case_plan_notu_guncelle` | Spec'te hiç yazmadık | Var (ground truth L3380, L3395) — ayrı 2 RPC, bizim `recete_guncelle` ile çakışmaz (farklı kapsam) |
| **B13** | 🟡 ORTA | `add_treatment_day` gövdesinde `gorev_log.aciklama` JSONB → `planned_time` | Spec'te bu detay yok | Mevcut: `jsonb_build_object('day_id', v_day_id, 'gun_no', v_day_no, 'label', ..., 'planned_time', COALESCE(p_planned_time::text, ''))` — ama `p_planned_time` NULL gelirse boş string |
| **B14** | 🟡 ORTA | `gorev_log.parent_id` zincir mekanizması | "Yeni: trigger ile sync" yazdık | Mevcut: `parent_id = önceki günün gorev_id` (her INSERT'te lookup) — **aynı iş, trigger değil, manuel** |
| **B15** | 🟡 ORTA | `close_case_with_remaining` RPC'si "yeni" dedik | "Yeni: stok iade + uygulanmadi" | Mevcut `close_case` sadece status='closed', yeni RPC gerekli ✅ — Y3 spec doğru |
| **B16** | 🟡 ORTA | `islem_log` tablosu kullanımı | Spec'te yazdık | Mevcut: `treatment_day_tamamla` `islem_log` yazmıyor, sadece `add_treatment_day` yazıyor (L3240) — yeni RPC'ler islem_log eklemeli |
| **B17** | 🟡 ORTA | `js/api.js:253-256` `pullTables` mapping | Spec'te "treatment_day_uygulamalar eklenecek" | Mevcut: `add_treatment_day, add_drug_administration, close_case` var — `treatment_day_tamamla` YOK, eksik mapping |
| **B18** | 🟢 DÜŞÜK | `caseGunEkle` handler | Spec'te "caseGunEkleOnayla" diye hayali isim | Mevcut: `caseGunEkle()` (handlers.js:225) — farklı isimlendirme |
| **B19** | 🟢 DÜŞÜK | `js/ui.js:4042, 4537` `treatment_day_tamamla` çağrı yerleri | Spec'te tek yerde yazdık | **2 farklı call site** var: birinde `p_not`, diğerinde sadece `p_day_id` |
| **B20** | 🟢 DÜŞÜK | `js/ui.js:4696` `add_treatment_day` çağrısı | Spec'te "yeni RPC ile değişecek" | Mevcut çağrı sadece 2 parametre — eğer mevcut RPC'yi koruyacaksak dokunmaya gerek yok |
| **B21** | 🟢 DÜŞÜK | `js/ui.js:4042` `treatment_day_tamamla` zaten idempotent değil | Self-review'da fark ettik | Canlıda zaten `RAISE EXCEPTION` — idempotent yapılırken **mevcut 3 parametreli imzayı korumalıyız** |


---

## 1. DB Drift Analizi (Ground Truth → Live DB)

### 1.1 Ground Truth Canonical Referans
- **Dosya:** `/root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql` (10,040 satır)
- **Kural (Pato 12):** Ara migration'lar (`*_fix.sql`, `*_revize.sql`, `*_v2.sql`) YANLIŞ referanstır

### 1.2 Kritik Tablo Şemaları (Ground Truth L+ Live DB)

#### `stok` (L30)
```sql
-- Ground truth
id text PRIMARY KEY,         -- ✅ text (stok_id FK text uyumlu)
urun_adi text NOT NULL,      -- ⚠️ Spec'te "stok.ad" yazdık, "stok.urun_adi" olmalı
kategori text,
birim text,
baslangic_miktar numeric DEFAULT 0,
esik numeric DEFAULT 0
```

#### `stok_hareket` (L39)
```sql
-- Ground truth
id text PRIMARY KEY,         -- ✅ text (Pato 12 K1 fix doğru)
stok_id text,                -- FK → stok.id (text)
tur text,                    -- ('Tedavi', 'Alış', 'İade' vb.)
miktar numeric,              -- pozitif=azalır, negatif=artar
notlar text,                 -- 'drug_admin:UUID' pattern
iptal boolean DEFAULT false
```

**Live DB doğrulama:** ✅ Eşleşiyor. `notlar` kolonu `drug_admin:UUID` pattern'i ile çalışıyor (ground truth L3279).

#### `gorev_log` (L48)
```sql
-- Ground truth
id uuid PRIMARY KEY DEFAULT gen_random_uuid(),  -- ⚠️ UUID (spec'te text yazdık, YANLIŞ)
hayvan_id text,                                 -- FK → hayvanlar.id (text)
gorev_tipi text,                                -- ('TEDAVI_GUN', 'ASI', vb.)
aciklama text,                                  -- JSONB string saklıyor!
hedef_tarih date,
tamamlandi boolean DEFAULT false,
tamamlanma_tarihi timestamptz,
parent_id text,                                 -- ✅ text (zincir için)
stok_id text,
miktar numeric,
hekim_id text,
kaynak text,
padok_hedef text,
iptal boolean DEFAULT false,
etken_kod text,
kapatan_ref text
```

**⚠️ DRİFT:** Spec'te `gorev_log.id = text` yazdık ama **`uuid`**. `INSERT` için `gen_random_uuid()` kullanılır (cast YAPILMAZ). BUG-059 spec'i yanlışlıkla bu hatayı yapmadı çünkü seans FK için `gorev_log.seans_admin_id` yazdık (gorev_log.id'ye değil, ayrı kolon). Ancak gözden geçirilmeli.

#### `treatment_days` (L2910)
```sql
-- Ground truth (L2910-2935)
id               uuid  PRIMARY KEY DEFAULT gen_random_uuid(),  -- ✅ uuid
case_id          uuid  NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
day_no           integer,                                       -- trigger ile otomatik artar
treatment_date   date  NOT NULL DEFAULT CURRENT_DATE,
notes            text,
created_at       timestamptz DEFAULT now(),

-- Migration 20260525000002: done tracking
tamamlandi         boolean     DEFAULT false,                  -- ✅ mevcut
tamamlanma_tarihi  timestamptz,                                -- ✅ mevcut
tamamlanma_notu    text,                                        -- ✅ mevcut

-- Migration 20260528000001: planned_time
planned_time TIME                                              -- ✅ ground truth'ta var
```

**Live DB doğrulama:** `planned_time` kolonu VAR ama **tüm 13 günde NULL** (hiç set edilmemiş). Demek ki:
- Ground truth'ta kolon tanımı var
- `add_treatment_day` çağrılarında `p_planned_time` hiç geçilmemiş (drift 2: canlı frontend bu parametreyi bilmiyor)
- `add_treatment_day` SQL body'si planned_time'ı INSERT ediyor (ground truth L3228) ama NULL gelirse NULL yazıyor

**BUG-059 etkisi:** BUG-059 için seans başına `planned_time` ayrıca `treatment_day_uygulamalar.planned_time` olarak gerekli. Bu kolon **yeni olmalı** (ground truth'ta treatment_days.planned_time gün seviyesinde, seans seviyesinde değil). İkisi farklı şey.

#### `drug_administrations` (L2936)
```sql
-- Ground truth
id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
treatment_day_id  uuid    NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
stok_id           text    REFERENCES public.stok(id),           -- ✅ text FK
drug_product_id   uuid    REFERENCES public.drug_products(id),
dose              numeric NOT NULL CHECK (dose > 0),
unit              text    NOT NULL,
route             text,                                          -- IM|IV|SC|PO|Topikal|Intrauterin
notes             text,
uygulanmadi       boolean DEFAULT false,                          -- ✅ mevcut
created_at        timestamptz DEFAULT now(),

CONSTRAINT drug_administrations_route_check
  CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin'))
```

**Live DB doğrulama:** ✅ Eşleşiyor. `uygulanmadi` kolonu zaten var. BUG-059 için `seans_admin_id` kolonu **yeni eklenecek** (K5 FK).

#### `cases` (live DB)
- `id` = uuid ✅
- `animal_id` = **DRİFT (B8)**: UUID + text karışık
- `status` = 'active' | 'closed' ✅
- `plan_notu` = text (YENİ bulgu, spec'te yoktu)
- `closed_at` = timestamptz

**B8 detay:** Live DB'de 5 vakanın `animal_id`'leri:
- `eb10376a...` → `1433f5f2-b60a-4ba1-9057-...` (UUID)
- `a09f0d0b...` → `H000142` (text)

Bu **drift**: BUG-059 spec'te `cases.animal_id` tipini düşünmedik çünkü `treatment_day_uygulamalar` FK olarak kullanmıyoruz (sadece `case_id` üzerinden animal_id'ye ulaşıyoruz). Ancak `gorev_log.hayvan_id` insert ederken `cases.animal_id`'yi kullanıyoruz — bu da Pato 12'nin yeni versiyonu: **hayvan_id text olarak saklanmalı, UUID hayvan_id'ler için `::text` cast gerekli**.


---

## 3. Frontend Drift Analizi (JS call sites + UI pattern)

### 3.1 Mevcut RPC Çağrı Yerleri (`grep` ile tespit)

| RPC | Call Site | Parametreler | Not |
|---|---|---|---|
| `add_treatment_day` | `js/ui.js:4696` | `{p_case_id, p_date}` | ⚠️ `p_planned_time` YOK (drift) |
| `treatment_day_tamamla` | `js/ui.js:4042` | `{p_day_id, p_not}` | B19: not parametreli |
| `treatment_day_tamamla` | `js/ui.js:4537` | `{p_day_id}` | B19: sadece day_id |
| `add_drug_administration` | `js/ui.js:4819` | `{p_day_id, p_stok_id, p_drug_product_id, p_dose, p_unit, p_route}` | ✅ Tam imza |
| `close_case` | `js/ui.js:4946` | `{p_case_id}` | ✅ |
| REST PATCH `drug_administrations` | `js/ui.js:5665` | drug_admin update | drug_id kaldırıldı, REST PATCH yine de var — deprecated olabilir |

### 3.2 `js/api.js` pullTables Mapping (L253-256)

```javascript
// Mevcut (live)
add_treatment_day:         ['cases','treatment_days'],
add_drug_administration:   ['stok','stok_hareket','drug_administrations'],
close_case:                ['cases'],
// treatment_day_tamamla mapping YOK — B17 drift
```

**BUG-059 için eklenecek:**
```javascript
add_treatment_day_with_sessions: ['cases', 'treatment_days', 'drug_administrations', 'stok', 'stok_hareket', 'islem_log'],
seans_tamamla:                   ['treatment_day_uygulamalar', 'drug_administrations', 'stok_hareket', 'gorev_log'],
recete_guncelle:                 ['cases', 'treatment_days', 'drug_administrations', 'stok', 'stok_hareket'],
close_case_with_remaining:       ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'gorev_log', 'stok_hareket'],
treatment_day_tamamla:           ['cases', 'treatment_days', 'gorev_log', 'drug_administrations', 'stok_hareket'],  // B17
```

### 3.3 UI Pattern (Mevcut)

**`js/utils/handlers.js:225`** — `case-gun-ekle` event handler'ı `caseGunEkle()` fonksiyonunu çağırıyor (B18, spec'te `caseGunEkleOnayla` diye hayali isim yazmıştık).

**Mevcut UI akışı** (process proc_107 + proc_108):
- `CaseDaySaatKaydet` → günün saatini kaydet (mevcut)
- `CaseDayNotKaydet` → günün notunu kaydet (mevcut)
- `CaseDrugSil` → ilaç sil (mevcut)
- `CaseDayTamamla` → gün tamamla (mevcut)
- `case-gun-ekle` → yeni gün ekle (mevcut, sadece tarih alıyor)

**BUG-059 için eklenecek UI:**
- `CaseSaatEkle(seans)` → seans ekle (saat + ilaç + doz + yol)
- `CaseSaatSil(seans_id)` → seans sil
- `CaseSaatTamamla(seans_id)` → seans done işaretle
- `CaseSaatDegistir(seans_id, yeni_saat)` → saat değiştir
- `CaseReceteGuncelle(yeni_plan)` → tüm planı sil + yeniden yaz

### 3.4 UI.js İç Yapısı (6828 satır, kritik risk)

Faz 5'te `js/ui.js`'e dokunmamız gereken yerler:
- **L4042:** `treatment_day_tamamla` çağrısı (idempotent güncelleme sonrası uyumlu hale getir)
- **L4537:** `treatment_day_tamamla` çağrısı (seanslar eklenince dual path)
- **L4696:** `add_treatment_day` çağrısı (korunacak, yeni RPC yan yana)
- **L4819:** `add_drug_administration` çağrısı (korunacak)
- **L4946:** `close_case` çağrısı → `close_case_with_remaining` dispatch (D3 fix)
- **YENİ:** L????: `add_treatment_day_with_sessions` çağrısı
- **YENİ:** L????: `seans_tamamla` çağrısı
- **YENİ:** L????: `recete_guncelle` çağrısı

**`renderTask` (L480+):** Görev kartında saat rozeti (`hedef_saat`) göstermek için güncelleme gerekli.

---

## 4. Sonuç — Spec/Plan Revizyonu Gerekli

### 4.1 Spec Revizyon Maddeleri (BUG-059 spec güncelleme)

| ID | Revizyon |
|---|---|
| **R1** | `add_treatment_day_with_sessions` RPC'sini YENİ OLARAK tut ama **amacını netleştir**: `add_treatment_day` + N×`add_drug_administration` yerine **tek transaction atomikliği + seans bazlı planned_time** sunuyor. Mevcut 2 RPC'ye ek değer. |
| **R2** | `treatment_day_tamamla` güncellemesinde `p_uygulanmadi_ids uuid[]` parametresini **KORU** (ground truth L3311). Self-review'da eklemediğimiz bu parametre mevcut ve bizim Y3 senaryosu için kritik. |
| **R3** | `treatment_day_tamamla` idempotent guard ekle (`IF v_day.tamamlandi THEN RETURN 'zaten tamamlandı'`), ama mevcut RAISE EXCEPTION'ı **KORUYARAK** değiştir (sessiz RETURN) |
| **R4** | `gorev_log.id` = **uuid** (text değil), BUG-059 spec'te bu detayı netleştir |
| **R5** | `cases.animal_id` drift'i: BUG-059 spec'te animal_id kullanmıyoruz ama `gorev_log.hayvan_id` insert ederken `cases.animal_id`'yi kopyalıyoruz — yeni RPC'lerde bu pattern korunmalı, UUID/text karışıklığına dikkat |
| **R6** | `treatment_day_uygulamalar.planned_time` kolonu (seans bazlı) **yeni olmalı** — `treatment_days.planned_time` (gün bazlı) ground truth'ta zaten var ama canlıda NULL |
| **R7** | `treatment_day_not_guncelle` ve `case_plan_notu_guncelle` RPC'leri mevcut — `recete_guncelle` ile çakışmaz, ayrı bırak |
| **R8** | Mevcut 5 vakaya (4 değil!) geriye uyumluluk hedefi — Faz 4'te snapshot 5 vakaya göre alınmalı |
| **R9** | `islem_log` audit pattern: sadece `add_treatment_day` yazıyor, diğer RPC'ler yazmıyor — yeni RPC'ler (`seans_tamamla`, `recete_guncelle`, `close_case_with_remaining`) islem_log'a yazmalı (drift: ground truth'ta islem_log sadece 1 yerde) |

### 4.2 Plan Revizyon Maddeleri (Implementation plan güncelleme)

| ID | Revizyon |
|---|---|
| **P1** | Faz 1 — `treatment_day_uygulamalar` tablosunda `planned_time` kolonu **yeni olacak** (gün seviyesinde `treatment_days.planned_time` zaten var, çakışma değil, farklı anlam) |
| **P2** | Faz 2 — `add_treatment_day_with_sessions` RPC'sinde `INSERT INTO stok_hareket` **mevcut `add_drug_administration` mantığıyla aynı** (notlar='drug_admin:' || v_id), tekrarlı yazım değil |
| **P3** | Faz 2 — `treatment_day_tamamla` güncellemesinde `p_uygulanmadi_ids uuid[]` parametresi KORUNACAK (DROP+CREATE yerine mevcut imzayı koru) |
| **P4** | Faz 5 — `js/api.js:253-256` pullTables mapping'e `treatment_day_tamamla` eklenecek (B17 fix) |
| **P5** | Faz 4 — Snapshot 4 vaka yerine **5 vakaya** göre alınacak (R8) |
| **P6** | Faz 5 — `caseGunEkle` (mevcut handler) + `caseGunEkleOnayla` (spec'te yazdığımız hayali isim) ayrımı netleşmeli |
| **P7** | Faz 6 — Senaryo A (geriye uyumlülük) **5 vakaya** uygulanmalı (4 değil) |

### 4.3 Aksiyon Planı (Kullanıcı Onayı)

**Sıradaki adımlar:**

1. ✅ **Bu dosya** (Faz 0 Bulguları) — yazıldı
2. ⏳ **Spec revizyonu** — R1-R9 maddelerini spec'e uygula, **kullanıcı onayı** al
3. ⏳ **Plan revizyonu** — P1-P7 maddelerini plan'a uygula
4. ⏳ **Yeniden sub-agent review** (1 tur) — revize spec + plan
5. ⏳ **Faz 1**'e geçiş (schema migration)

**Kullanıcıya soru:**

```
"FAZ 0 TAMAMLANDI. 21 bulgu tespit edildi (5 kritik, 7 yüksek, 5 orta, 4 düşük).

Kritik bulgular (revizyon gerekli):
- B1: treatment_day_tamamla'ya p_uygulanmadi_ids eklemeyi unuttuk
- B2: add_treatment_day canlıda sadece 2 parametre alıyor (p_planned_time yok)
- B3: Stok INSERT zaten add_drug_administration'da var (K2 fix zaten uygulanmış)
- B4: add_treatment_day_with_sessions RPC'si 'yeni' değil, sarmalayıcı
- B5: 3 review turu p_uygulanmadi_ids'i kaçırdı

Revizyon yapmadan Faz 1'e geçmek RİSKLİ (spec yanlış varsayımlarla yazıldı).

Onaylıyor musun:
- (a) Spec + Plan'ı revize edip yeniden review (önerilen, 1-2 saat)
- (b) Revize etmeden Faz 1'e geç, hataları implementasyonda düzelt (riskli)
- (c) Başka bir yaklaşım"
```

