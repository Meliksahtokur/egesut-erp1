# Aşılama Tam Mimari — Design Document

> **Tarih:** 2026-06-12
> **Branch:** `feature/asilama-tam-mimari`
> **Yazar:** Pi agent (MiniMax-M3) + Kullanıcı
> **Durum:** Brainstorming TAMAMLANDI → Implementation plan yazımı BEKLİYOR
> **İlgili:** `docs/research/2026-06-12-asi-sistemi-mevcut-durum-ve-dilek.md`

---

## 1. Yönetici Özeti

### 1.1 Problem
Sistemde aşılama altyapısı 3 ayrı parçadan oluşuyor ve **birbirine bağlı değil**:
1. **Tanımlar** (`vaccines`, `vaccination_schedule`) → DB'de var ama UI'dan yönetilemez, kurallar hardcoded
2. **Protokol** (`protokol_instance`, `protokol_eksik_tara`) → çalışıyor ama sadece ilaç/üreme, aşı taramıyor
3. **UI** → aşı uygulama var ama tanım yönetimi yok, aşı durumu görünümü eksik

**Eksikler:**
- Doğumla buzağı aşı takvimi tetiklenmiyor
- Yıllık tekrar pasif (sadece uygulandıktan sonra hatırlat)
- Karma aşı kavramı modellenmemiş (1 aşı N hastalık)
- Rapel kuralları kodda, veri tabanında değil

### 1.2 Çözüm — 3 Katmanlı Mimari

```
┌─ KATMAN 1: TANIMLAR (CRUD UI) ─────────────────────────┐
│ • vaccines + vaccine_components (karma aşı için)        │
│ • vaccination_schedule (protokol tanımları)              │
│ • asi_tekrar_kurallari (YENİ — UI'dan yönetilir)        │
│   "ilk aşıda 28 gün sonra", "yıllık 365 gün", "yok"      │
└─────────────────────────────────────────────────────────┘
                           ↓ referans
┌─ KATMAN 2: PROTOKOL (mevcut + genişletme) ─────────────┐
│ • protokol_instance — yeni alttip: ASITAKVIMI/BUZAGI,  │
│   ASITAKVIMI/YETISKIN                                    │
│ • vaccination_log — zaten var                             │
│ • gorev_log — yeni kolon: vaccine_id, protokol_adi      │
└─────────────────────────────────────────────────────────┘
                           ↓ okur
┌─ KATMAN 3: SCAN (protokol_eksik_tara entegre) ─────────┐
│ • Mevcut 3 bölüm + 3 yeni (D, E, F) aşı bölümü         │
│ • Hangi kural geçerli → asi_tekrar_kurallari.tablo'dan │
│ • vaccination_log 4. arama yeri olarak eklenir           │
└─────────────────────────────────────────────────────────┘
```

### 1.3 Tasarım Prensipleri
- **Kurallar veri, kod değil** — "30 gün sonra" gibi değerler DB'de
- **Geriye uyumluluk** — mevcut `add_vaccination`, `protokol_eksik_tara` bozulmaz, genişler
- **Tek dismiss modeli** — aşı uyarıları da `protokol_dismiss` ile dismiss edilebilir
- **Idempotent** — aynı koşulda 2 kez çalışsa 2 kez INSERT yapmaz
- **Karma aşı modeli** — 1 aşı N hastalığa karşı koruma

### 1.4 Efor
**14-18 saat** (DB migration 3-4h, RPC 4-5h, UI 4-5h, test 3-4h)

---

## 2. Veri Modeli

### 2.1 Yeni Tablolar (2 adet)

#### 2.1.1 `vaccine_components` — Karma aşı içeriği
```sql
CREATE TABLE vaccine_components (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vaccine_id uuid NOT NULL REFERENCES vaccines(id) ON DELETE CASCADE,
  disease_code text NOT NULL,  -- 'SARBON','BVD','IBR','LEPTO','SHP','CORONA','ROTA','ECOLI','BRSV','PIOGEN','PIROZ','TETANOZ'
  created_at timestamptz DEFAULT now(),
  UNIQUE(vaccine_id, disease_code)
);
CREATE INDEX idx_vaccine_components_disease ON vaccine_components(disease_code);
```

**Amaç:** 1 aşı N hastalığa karşı koruma sağlar. Mevcut `vaccines.disease_target` tek değer tutar, bu yüzden karma aşıları (Coglavax, Vac-Sules Feedlot) ifade edemez.

**Seed örneği:**
```sql
-- Coglavax: Şarbon + Piroplazmoz + Tetanoz
INSERT INTO vaccine_components (vaccine_id, disease_code)
SELECT id, 'SARBON' FROM vaccines WHERE name='Coglavax';
INSERT INTO vaccine_components (vaccine_id, disease_code)
SELECT id, 'PIROZ' FROM vaccines WHERE name='Coglavax';
INSERT INTO vaccine_components (vaccine_id, disease_code)
SELECT id, 'TETANOZ' FROM vaccines WHERE name='Coglavax';

-- Vac-Sules Feedlot: BVD + IBR + BRSV + Piogen
INSERT INTO vaccine_components (vaccine_id, disease_code)
SELECT id, unnest(ARRAY['BVD','IBR','BRSV','PIOGEN'])
FROM vaccines WHERE name='Vac-Sules Feedlot';
```

#### 2.1.2 `asi_tekrar_kurallari` — UI'dan yönetilen tekrar kuralları
```sql
CREATE TABLE asi_tekrar_kurallari (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vaccine_id uuid NOT NULL REFERENCES vaccines(id) ON DELETE CASCADE,
  applies_to text NOT NULL CHECK (applies_to IN ('ilk_asida','yillik_tekrarda','genel')),
  next_dose_offset_days integer,  -- NULL = tek doz (rapel/tekrar yok)
  max_validity_days integer,      -- koruma süresi
  notes text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(vaccine_id, applies_to)
);
CREATE INDEX idx_asi_tekrar_kurallari_vaccine ON asi_tekrar_kurallari(vaccine_id);
```

**`applies_to` semantiği:**
- `ilk_asida`: Hayvanın aşı geçmişi yoksa (ilk kez aşılanıyor) → 21-30 gün sonra rapel
- `yillik_tekrarda`: Hayvanın aşı geçmişi varsa (yıllık tekrar) → 365 gün sonra
- `genel`: Fark yoksa (tek dozluk aşılar) → aynı kural

**`next_dose_offset_days` anlamı:**
- NULL: Bu aşı için o durumda **rapel/tekrar YOK** (tek doz)
- 0: Aynı gün
- 21: 3 hafta sonra
- 28: 4 hafta sonra
- 365: 1 yıl sonra

**`max_validity_days` anlamı:** "Bu kadar gün geçtiyse koruma sayılmaz, yeniden aşıla." (aşı zamanı geçmişse)

**Seed örnekleri (12 aşı × ~2 kural = ~24 satır):**
```sql
-- Karma aşılar (Coglavax, Vac-Sules)
INSERT INTO asi_tekrar_kurallari (vaccine_id, applies_to, next_dose_offset_days, max_validity_days, notes)
SELECT id, 'ilk_asida', 28, 30, 'İlk doz sonrası 4 hafta'
FROM vaccines WHERE name IN ('Coglavax', 'Vac-Sules Feedlot');

INSERT INTO asi_tekrar_kurallari (vaccine_id, applies_to, next_dose_offset_days, max_validity_days, notes)
SELECT id, 'yillik_tekrarda', 365, 395, 'Yıllık tekrar yeterli'
FROM vaccines WHERE name IN ('Coglavax', 'Vac-Sules Feedlot');

-- Solo aşılar (Şarbon, BVD, IBR, Lepto, BRSV, Piogen, Clostridium)
INSERT INTO asi_tekrar_kurallari (vaccine_id, applies_to, next_dose_offset_days, max_validity_days, notes)
SELECT id, 'genel', 365, 395, 'Tek doz, yıllık tekrar yeterli'
FROM vaccines WHERE name IN ('Şarbon Aşısı', 'BVD', 'IBR', 'Leptospirosis', 'BRSV', 'Piogen', 'Clostridium');
```

### 2.2 Mevcut Tablolarda Değişiklikler (3 ALTER)

| Tablo | Değişiklik | Amaç |
|-------|-----------|------|
| `vaccines` | `+ is_combo boolean DEFAULT false` | Karma mı solo mu filtresi |
| `gorev_log` | `+ vaccine_id uuid FK → vaccines` | Aşı görevinde hangi aşı? |
| `gorev_log` | `+ protokol_adi text` | Hangi protokol? ('BUZAGI_ASI','YILLIK_ASI','DOGUM_SONRASI_ASI','ILERI_GEBE_ASI') |

**Migration örneği:**
```sql
-- Migration 3: gorev_log kolonları
ALTER TABLE gorev_log
  ADD COLUMN IF NOT EXISTS vaccine_id uuid REFERENCES vaccines(id),
  ADD COLUMN IF NOT EXISTS protokol_adi text;

-- Index'ler
CREATE INDEX IF NOT EXISTS idx_gorev_log_vaccine_id
  ON gorev_log(vaccine_id) WHERE vaccine_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_gorev_log_protokol_adi
  ON gorev_log(protokol_adi) WHERE protokol_adi IS NOT NULL;
```

### 2.3 Yeni `protokol_instance` Alttipleri (mevcut tabloya INSERT)

- `tip='ASITAKVIMI', alttip='BUZAGI'` → Buzağı aşı takvimi
- `tip='ASITAKVIMI', alttip='YETISKIN'` → Yetişkin yıllık takvim
- `tip='ASITAKVIMI', alttip='DOGUM_SONRA'` → Doğum sonrası inek aşı takvimi

**Bu instance'lar:**
- Bir hayvanın tüm aşı geçmişini tutar
- `protokol_eksik_tara` bu instance'lara bağlı görevleri tarar
- `protokol_dismiss` ile aşı adımları da dismiss edilebilir

### 2.4 `protokol_dismiss` Genişletme

```sql
ALTER TABLE protokol_dismiss
  ADD COLUMN IF NOT EXISTS vaccine_id uuid REFERENCES vaccines(id);

-- Yeni UNIQUE: aşı için
CREATE UNIQUE INDEX IF NOT EXISTS uq_protokol_dismiss_asi
  ON protokol_dismiss(hayvan_id, vaccine_id, protokol)
  WHERE vaccine_id IS NOT NULL;
```

Mevcut UNIQUE(hayvan_id, etken_kod, protokol) korunur (ilaç için), yeni UNIQUE aşı için eklenir (NULL olmayanlar).

### 2.5 `vaccination_schedule` Genişletme (mevcut 5 → ~15 seed)

**Mevcut:**
| target_type | vaccine | timing_type | gün |
|-------------|---------|-------------|-----|
| buzağı | BVD | yas | 60 |
| buzağı | BVD | yas | 120 |
| buzağı | Şarbon | yas | 180 |
| düve | IBR | yas | 365 |
| inek | Leptospirosis | dogum_sonra | 30 |

**Yeni eklenecekler (10+ satır):**
| target_type | vaccine | timing_type | gün |
|-------------|---------|-------------|-----|
| buzağı | E.coli | yas | 7 |
| buzağı | E.coli | yas | 28 (rapel) |
| buzağı | Rotavirus | yas | 7 |
| buzağı | Rotavirus | yas | 28 (rapel) |
| buzağı | Coronavirus | yas | 7 |
| buzağı | Coronavirus | yas | 28 (rapel) |
| buzağı | BRSV | yas | 90 |
| buzağı | BRSV | yas | 120 (rapel) |
| buzağı | Piogen | yas | 120 |
| buzağı | Clostridium | yas | 90 |
| buzağı | Clostridium | yas | 120 (rapel) |
| inek | Şarbon | yas | 365 (yetişkin yıllık) |
| inek | BVD | yas | 365 (yetişkin yıllık) |
| inek | IBR | yas | 365 (yetişkin yıllık) |
| düve | Şarbon | yas | 365 (düve yıllık) |
| düve | BVD | yas | 365 (düve yıllık) |

---

## 3. RPC Sözleşmeleri (4 Yeni RPC)

### 3.1 `buzagi_asi_gorev_olustur(p_buzagi_id text)`
```sql
RETURNS jsonb
-- {ok, olusturulan: int, atlanan: int, hata_sayisi: int, detaylar: [{vaccine_id, hedef_tarih, durum}]}
LANGUAGE plpgsql SECURITY DEFINER
```

**Mantık (adım adım):**
1. Buzağının `dogum_tarihi`'ni al (`hayvanlar` tablosundan)
2. `vaccination_schedule` (target_type IN ('buzağı','düve','tüm'), timing_type='yas') tara
3. Her schedule için: `hedef_tarih = dogum_tarihi + timing_days`
4. **Idempotent kontrol:** Aynı hayvan + vaccine_id + sequence_order + hedef tarihli `gorev_log` varsa → atla
5. **Dismiss kontrolü:** `protokol_dismiss WHERE hayvan_id=X AND vaccine_id=Y AND protokol='BUZAGI_ASI_PROTOKOL'` varsa → atla
6. Yoksa INSERT: 
   - `gorev_tipi='BUZAGI_ASI'`
   - `vaccine_id=schedule.vaccine_id`
   - `protokol_adi='BUZAGI_ASI'`
   - `aciklama='💉 {vaccine.name} (sequence_order. doz)'`
   - `hedef_tarih`
   - `stok_id=vaccines.stock_item_id`
   - `miktar=vaccines.dose`
   - `kaynak='BUZAGI-ASI-{buzagi_id}'`
7. Instance oluştur (yoksa): `protokol_instance(tip='ASITAKVIMI', alttip='BUZAGI', kaynak_ref='BUZAGI-ASI-{id}')`

**Tetikleyici:** `dogum_kaydet` RPC içinde (buzağı INSERT'ten sonra)

**Geriye uyumluluk:** Mevcut `dogum_kaydet` davranışı değişmez, sadece sonuna `buzagi_asi_gorev_olustur(buzagi_id)` çağrısı eklenir.

### 3.2 `yillik_asi_gorev_kontrol()`
```sql
RETURNS jsonb
-- {ok, olusturulan: int, atlanan: int, hata_sayisi: int, detaylar: [{hayvan_id, vaccine_id, hedef_tarih, durum}]}
LANGUAGE plpgsql SECURITY DEFINER
```

**Mantık (adım adım):**
1. Tüm aktif hayvanları al (`hayvanlar WHERE durum='Aktif' AND age(dogum_tarihi) >= 365 days`)
2. `asi_tekrar_kurallari` (applies_to IN ('yillik_tekrarda','genel'), next_dose_offset_days IS NOT NULL) tara
3. Her (hayvan, kural) kombinasyonu için:
   a. Son `vaccination_log` tarihini bul (animal_id + vaccine_id)
   b. `next_due_date = COALESCE(son.tarihi + next_dose_offset_days, dogum_tarihi + 365)`
   c. `next_due_date <= bugün + 30` VE tamamlanmamış `gorev_log` yoksa → INSERT:
      - `gorev_tipi='YILLIK_ASI'`
      - `vaccine_id`
      - `protokol_adi='YILLIK_ASI'`
      - `aciklama='💉 {vaccine.name} (yıllık tekrar)'`
      - `hedef_tarih=next_due_date`
      - `stok_id, miktar`
      - `kaynak='YILLIK-ASI-{hayvan_id}'`
   d. `protokol_dismiss` kontrolü (atla)

**Tetikleyici:** pg_cron `0 3 * * 1` (Pazartesi 03:00, haftalık)

**Performans:** Index'ler yeterli (idx_vaccination_log_animal_vaccine, idx_asi_tekrar_kurallari_vaccine)

### 3.3 `asi_protokol_tara(p_dry_run boolean DEFAULT true, p_hayvan_id text DEFAULT NULL)`
```sql
RETURNS jsonb
-- p_dry_run=true:
--   {olusturulacak: [{hayvan_id, vaccine_id, adim, hedef_tarih, durum}],
--    mevcut_gorev_var: [{hayvan_id, vaccine_id, gorev_id}],
--    eksik_gecmis: [{hayvan_id, kupe_no, durum: 'ilk_asi_bekliyor'|'yillik_gecmis'}],
--    hatalar: [...]}
--
-- p_dry_run=false:
--   {olusturulan: int, atlanan: int, hatalar: [...]}
LANGUAGE plpgsql SECURITY DEFINER
```

**3 Bölüm:**

#### A. Buzağı Aşıları (0-365 gün)
- "Süt İçen Buzağı" + "Düve" gruplarındaki aktif hayvanlar
- `vaccination_schedule` (target_type IN ('buzağı','düve','tüm'), timing_type='yas')
- Her schedule için: `hedef = dogum_tarihi + timing_days`
- **5 yerde arama:** `gorev_log`, `uygulama_log`, `drug_administrations`, `vaccination_log`, `protokol_dismiss`
- Durum: `'eksik'` | `'yaklasan'` | `'tamamlandi'`

#### B. Yetişkin Yıllık (>365 gün, aktif inek/düve)
- `asi_tekrar_kurallari` (applies_to IN ('yillik_tekrarda','genel'), next_dose_offset_days IS NOT NULL)
- Son `vaccination_log` + `asi_tekrar_kurallari.next_dose_offset_days`
- `bugün >= next_due - 14` → `'eksik/yaklasan'`
- `bugün > next_due + max_validity_days` → `'koruma_gecmis'`

#### C. Doğum Sonrası İnek (son 70 gün doğum)
- `vaccination_schedule` (target_type='inek', timing_type='dogum_sonra')
- `hedef = dogum.tarihi + timing_days`

**Yardımcı fonksiyonlar (5 yerde arama):**
```sql
-- Tek arama fonksiyonu: aşı uygulandı mı?
CREATE OR REPLACE FUNCTION _asi_eksik_mi(
  p_hayvan_id text,
  p_vaccine_id uuid,
  p_hedef_tarih date,
  p_tolerans_gun int DEFAULT 3
) RETURNS TABLE(bulundu boolean, ref text, tarih timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
BEGIN
  -- 1. gorev_log
  RETURN QUERY
  SELECT true, 'gorev_log:' || g.id::text, g.tamamlanma_tarihi
  FROM gorev_log g
  WHERE g.hayvan_id = p_hayvan_id
    AND g.vaccine_id = p_vaccine_id
    AND g.tamamlandi = true
    AND g.hedef_tarih BETWEEN p_hedef_tarih - p_tolerans_gun AND p_hedef_tarih + p_tolerans_gun
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- 2. vaccination_log (YENİ - önce yoktu)
  RETURN QUERY
  SELECT true, 'vaccination_log:' || vl.id::text, vl.created_at
  FROM vaccination_log vl
  WHERE vl.animal_id = p_hayvan_id
    AND vl.vaccine_id = p_vaccine_id
    AND vl.vaccination_date BETWEEN p_hedef_tarih - p_tolerans_gun AND p_hedef_tarih + p_tolerans_gun
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- 3-5. uygulama_log, drug_administrations, protokol_dismiss (mevcut pattern)
  -- ...
END;
$$;
```

### 3.4 `gecmise_asi_ekle(p_animal_id text, p_vaccine_id uuid, p_tarih date, p_dose numeric, p_notes text)`
```sql
RETURNS jsonb
-- {ok, mesaj, vaccination_log_id, sonraki_asi_tarihi, yillik_gorev_id}
LANGUAGE plpgsql SECURITY DEFINER
```

**Mantık (adım adım):**
1. **Tarih validasyon:** `dogum_tarihi + 30 gün <= p_tarih <= bugün` (gelecekte olamaz)
2. `add_vaccination(animal_id, vaccine_id, p_tarih, p_dose, p_notes)` çağır
   - vaccination_log INSERT (next_due_date hesaplanır)
   - Stok düşümü (trg_vaccination_stok)
   - islem_log
3. `vaccination_log.next_due_date` oku
4. `next_due_date > bugün` ise → `YILLIK_ASI` gorev oluştur (yukarıdaki mantıkla)
5. `protokol_instance` ASITAKVIMI/YETISKIN oluştur (yoksa)
6. Sonuç: `{ok: true, mesaj: 'Aşı eklendi, sonraki tekrar 2027-06-12 için planlandı'}`

**Tetikleyici:** UI — "Geçmişe Aşı Ekle" butonu (modal)

---

## 4. UI Akışları

### 4.1 Ekran 1: Aşı Tanımları

**Konum:** `index.html` → yeni sekme "Aşı Tanımları" veya `tanitimlar.html` ayrı sayfa

**Layout:**
```
┌─ Aşı Tanımları ───────────────────────────────────────────────┐
│  📋 Aşılar (12)              🗓️ Schedule (15+)               │
│  ➕ Yeni Aşı                    ➕ Yeni Schedule               │
│                                                                  │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║ 💉 Coglavax (KARMA)                          [Düzenle]   ║  │
│  ║ Hastalıklar: Şarbon, Piroplazmoz, Tetanoz                 ║  │
│  ║ ─────────────────────────────────────────                 ║  │
│  ║ Tekrar Kuralları:                                        ║  │
│  ║  • İlk aşıda      → 28 gün sonra (rapel)   [Düzenle]    ║  │
│  ║  • Yıllık tekrarda → 365 gün sonra          [Düzenle]    ║  │
│  ║ Doz: 2 ml, SC, repeat: 365 gün                          ║  │
│  ║ Stok: VAR-5 (var: 12, kritik: 3)                        ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                  │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║ 💉 BVD (solo)                                [Düzenle]   ║  │
│  ║ Hastalıklar: BVD                                          ║  │
│  ║ Tekrar Kuralları:                                        ║  │
│  ║  • İlk aşıda     → 21 gün sonra (rapel)    [Düzenle]    ║  │
│  ║  • Yıllık tekrarda → 365 gün sonra          [Düzenle]    ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                  │
│  📅 Schedule Tanımları                                          │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║ Buzağı, 60. gün, BVD 1. doz                              ║  │
│  ║   sonraki: BVD 2. doz (120. gün)                         ║  │
│  ║   sonraki: Şarbon 1. doz (180. gün)                      ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
└──────────────────────────────────────────────────────────────────┘
```

**JS Hook'ları:**
- `loadVaccines()` → `db.from('vaccines').select('*, components:vaccine_components(*), rules:asi_tekrar_kurallari(*)')`
- `editVaccine(id)` → modal aç
- `saveVaccine(form)` → `db.from('vaccines').update(...).eq('id', id)` + cascade rules

### 4.2 Aşı Düzenleme Modal

```
╔════════════════════════════════════════════════════╗
║ Aşı Düzenle — Coglavax                            ║
╠════════════════════════════════════════════════════╣
║ Ad: [Coglavax           ]                         ║
║ Tip: ( ) Solo   (•) Karma                         ║
║                                                    ║
║ Hastalıklar (multi-select):                        ║
║   ☑ Şarbon    ☐ BVD    ☐ IBR                      ║
║   ☑ Piroplazmoz  ☐ BRSV  ☐ Lepto                  ║
║   ☑ Tetanoz   ☐ Rota   ☐ Corona                   ║
║                                                    ║
║ Doz: [2] ml,  Rota: (•) SC  ( ) IM                ║
║ Tekrar: [365] gün                                 ║
║ Stok bağlantısı: [Stok:5 - VAR  ▼]                ║
║ Zorunlu: ☑                                        ║
║                                                    ║
║ ── Tekrar Kuralları ──                             ║
║ Bağlam: [İlk aşıda       ▼]                       ║
║   Sonraki doz: [28] gün sonra                     ║
║   Max geçerlilik: [30] gün                        ║
║   [+ Yeni kural ekle]                             ║
║                                                    ║
║ Bağlam: [Yıllık tekrarda ▼]                       ║
║   Sonraki doz: [365] gün sonra                    ║
║   [+ Yeni kural ekle]                             ║
║                                                    ║
║ [Kaydet]  [İptal]                                 ║
╚════════════════════════════════════════════════════╝
```

### 4.3 Ekran 2: Aşı Durumu

**Konum:** `index.html` → yeni sekme "Aşı Durumu" veya görevler sekmesine tab ekleme

**Layout:**
```
┌─ Aşı Durumu ─────────────────────────────────────────────┐
│  🔍 Son Tarama: 2026-06-12 14:30                        │
│  [Taramayı Yenile]  [Onayla ve Oluştur]                 │
│                                                            │
│  📊 Özet:                                                 │
│   • Oluşturulacak görev: 12 (3 buzağı × 4 aşı)           │
│   • Aşı kaydı eksik yetişkin: 5 hayvan                   │
│   • Zamanı geçmiş aşı: 2 hayvan                          │
│   • Tamamlanan: 8 (son 24 saat)                          │
│                                                            │
│  ── Filtreler ──                                          │
│  [Tümü] [Buzağı] [Yetişkin] [Eksik] [Yaklaşan]           │
│                                                            │
│  ╔══ Oluşturulacak Görevler (12) ══╗                    │
│  ║ 🔴 H000152 — 70 günlük BVD 1. doz    [+Oluştur]     ║ │
│  ║ 🔴 H000152 — 70 günlük BVD 2. doz    [+Oluştur]     ║ │
│  ║ 🟡 H000153 — 95 günlük Şarbon         [+Oluştur]     ║ │
│  ║ ...                                          ║ │
│  ╚════════════════════════════════════════════╝         │
│                                                            │
│  ╔══ Aşı Kaydı Olmayan Yetişkinler (5) ══╗              │
│  ║ 🐄 4521 (4 yaş, inek)                            ║    │
│  ║    Son aşı kaydı: YOK                              ║    │
│  ║    [Şimdi Aşıla]  [Geçmişe Aşı Ekle]  [Atla]       ║    │
│  ║ 🐄 4523 (3 yaş, düve)                            ║    │
│  ║    Son aşı: 14 ay önce (geç kalmış)               ║    │
│  ║    [Şimdi Aşıla]  [Geçmişe Aşı Ekle]  [Atla]       ║    │
│  ╚════════════════════════════════════════════╝         │
└──────────────────────────────────────────────────────────┘
```

**JS Hook'ları:**
- `loadAsiDurumu()` → `rpc('asi_protokol_tara', {p_dry_run: true})`
- `onaylaVeOlustur()` → `rpc('asi_protokol_tara', {p_dry_run: false})` + toast
- `hayvanAsila(hayvan_id)` → "Aşı Uygula" modal aç
- `hayvanaGecmisiEkle(hayvan_id)` → "Geçmişe Aşı Ekle" modal aç

### 4.4 Ekran 3: Dashboard Uyarı Bandı

**Konum:** Mevcut dashboard (`loadDash()`), doğum bandı altına 2 yeni band

**Layout:**
```
┌─ Dashboard ────────────────────────────────────────┐
│ 📅 Yaklaşan Doğumlar (5)                           │
│   H000150 — 12 gün kaldı                          │
│   ...                                              │
│                                                      │
│ 💉 Yaklaşan Aşılar (12)                       [→] │
│   3 buzağı — BVD/Şarbon/E.coli planı              │
│   9 yetişkin — yıllık tekrar zamanı geldi         │
│                                                      │
│ ⚠️ Aşı Kaydı Eksik (5)                       [→] │
│   5 yetişkin — geçmişe aşı ekle veya şimdi aşıla  │
└──────────────────────────────────────────────────────┘
```

**JS:**
```js
// loadDash() içinde:
const asiOzet = await rpc('asi_protokol_tara', {p_dry_run: true});
renderDashboardBand('asi-yaklasan', asiOzet.olusturulacak.length, 'aşı planı');
renderDashboardBand('asi-eksik', asiOzet.eksik_gecmis.length, 'aşı kaydı bekliyor');
```

### 4.5 Modal: Geçmişe Aşı Ekle

**Tetikleyici:** Hayvan detay → Sağlık sekmesi → "Geçmişe Aşı Ekle" butonu

```
╔══════════════════════════════════════════════════╗
║ Geçmişe Aşı Ekle — 4521 (inek, 4 yaş)           ║
╠══════════════════════════════════════════════════╣
║ Aşı: [Coglavax (karma, Şarbon+Piroz+Tetanoz) ▼] ║
║ Tarih: [📅 2026-01-15]                           ║
║       (1 yıl 5 ay önce, son 18 ay içinde)         ║
║       Geçerli aralık: 2018-06-12 ↔ 2026-06-12    ║
║ Doz: [2] ml                                       ║
║ Notlar: [...]                                     ║
║                                                    ║
║ ── Önizleme ──                                    ║
║ Sonraki yıllık tekrar: 2027-01-15 (planlanacak)   ║
║                                                    ║
║ [Ekle]  [İptal]                                   ║
╚══════════════════════════════════════════════════╝
```

**JS:** `saveGecmisAsi()` → `rpc('gecmise_asi_ekle', {...})` → toast

### 4.6 Modal: Aşı Uygula (Mevcut Genişletme)

**Mevcut `m-vaccine` modal + 1 yeni checkbox:**
```
╔══════════════════════════════════════════════════╗
║ Aşı Uygula — 4521                                 ║
╠══════════════════════════════════════════════════╣
║ Aşı: [BVD ▼]                                      ║
║ Tarih: [📅 bugün]                                 ║
║ Doz: [2] ml                                       ║
║ Notlar: [...]                                     ║
║                                                    ║
║ ☑ Bu bir takip aşısı (görev kapatılacak)          ║
║   İlgili görev: "BVD 2. doz" (15.06.2026)          ║
║                                                    ║
║ [Uygula]  [İptal]                                  ║
╚══════════════════════════════════════════════════╝
```

**Yeni davranış:** Checkbox işaretliyse → `add_vaccination` sonrası `trg_dinle_vaccination` zaten `_gorev_dinle` çağırır, görev otomatik kapanır. Manuel eşleştirmeye gerek yok.

---

## 5. Scan Entegrasyonu (`protokol_eksik_tara` Genişletme)

**Strateji:** Mevcut RPC'ye **D, E, F bölümleri** ekle. Tek sonuç, tek dismiss modeli, UI bütünlüğü.

### 5.1 Mevcut 3 Bölüm (KORUNUR)
- A. Doğum Sonrası Protokol (0-63 gün)
- B. İleri Gebe Protokol (240-265 gün)
- C. Kızgınlık Takibi (55-75 gün)

### 5.2 Yeni Bölümler

**D. BUZAGI AŞI PROTOKOLÜ** (0-365 gün)
- "Süt İçen Buzağı" + "Düve" gruplarındaki aktif hayvanlar
- `vaccination_schedule` (target_type IN ('buzağı','düve','tüm'), timing_type='yas')
- Her schedule için: `hedef = dogum_tarihi + timing_days`
- **5 yerde arama:** `gorev_log`, `uygulama_log`, `drug_administrations`, **`vaccination_log` (YENİ)**, `protokol_dismiss`
- Durum: `'eksik'` | `'yaklasan'` | `'tamamlandi'`
- **Dismiss:** `protokol='BUZAGI_ASI_PROTOKOL'`

**E. YETİŞKİN YILLIK AŞI PROTOKOLÜ** (>365 gün, aktif inek/düve)
- `asi_tekrar_kurallari` (applies_to IN ('yillik_tekrarda','genel'), next_dose_offset_days IS NOT NULL)
- Her kural için: son `vaccination_log` tarihi
- `next_due = COALESCE(son.tarihi + next_dose_offset_days, dogum_tarihi + 365)`
- Mantık:
  - Hiç aşı yoksa + hayvan >= 365 günlük → "hiç aşılanmamış" → `'eksik'`
  - `bugün >= next_due - 14` → `'eksik'`
  - `bugün >= next_due` ve `<= next_due + 14` → `'yaklasan'`
  - `bugün > next_due + max_validity_days` → `'koruma_gecmis'` (yeniden aşıla)
- **Dismiss:** `protokol='YILLIK_ASI_PROTOKOL'`

**F. DOĞUM SONRASI İNEK AŞI PROTOKOLÜ** (son 70 gün doğum)
- `vaccination_schedule` (target_type='inek', timing_type='dogum_sonra')
- `hedef = dogum.tarihi + timing_days`
- 5 yerde arama + dismiss (`protokol='DOGUM_SONRASI_ASI_PROTOKOL'`)

### 5.3 Yardımcı Fonksiyon: `_asi_eksik_mi`

```sql
CREATE OR REPLACE FUNCTION public._asi_eksik_mi(
  p_hayvan_id text,
  p_vaccine_id uuid,
  p_hedef_tarih date,
  p_tolerans_gun int DEFAULT 3
) RETURNS TABLE(bulundu boolean, ref text, tarih timestamptz, kaynak text)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  v_start date := p_hedef_tarih - p_tolerans_gun;
  v_end date := p_hedef_tarih + p_tolerans_gun;
BEGIN
  -- 1. gorev_log (tamamlanmış)
  RETURN QUERY
  SELECT true, 'gorev_log:' || g.id::text, g.tamamlanma_tarihi, 'gorev_log'::text
  FROM gorev_log g
  WHERE g.hayvan_id = p_hayvan_id
    AND g.vaccine_id = p_vaccine_id
    AND g.tamamlandi = true
    AND g.hedef_tarih BETWEEN v_start AND v_end
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- 2. vaccination_log (YENİ - 4. arama yeri)
  RETURN QUERY
  SELECT true, 'vaccination_log:' || vl.id::text, vl.created_at, 'vaccination_log'::text
  FROM vaccination_log vl
  WHERE vl.animal_id = p_hayvan_id
    AND vl.vaccine_id = p_vaccine_id
    AND vl.vaccination_date BETWEEN v_start AND v_end
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- 3. uygulama_log (etken_kod ile)
  RETURN QUERY
  SELECT true, 'uygulama_log:' || u.id::text, u.tarih::timestamptz, 'uygulama_log'::text
  FROM uygulama_log u
  WHERE u.hayvan_id = p_hayvan_id
    AND u.etken_kod = public._etken_kod_bul(NULL, p_vaccine_id)
    AND u.tarih BETWEEN v_start AND v_end
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- 4. drug_administrations (tedavi yolu)
  RETURN QUERY
  SELECT true, 'drug_admin:' || da.id::text, da.created_at, 'drug_administrations'::text
  FROM drug_administrations da
  JOIN treatment_days td ON td.id = da.treatment_day_id
  JOIN cases c ON c.id = td.case_id
  WHERE c.animal_id = p_hayvan_id
    AND public._etken_kod_bul(da.stok_id, NULL) = public._etken_kod_bul(NULL, p_vaccine_id)
    AND da.created_at::date BETWEEN v_start AND v_end
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- 5. protokol_dismiss (kullanıcı reddi)
  RETURN QUERY
  SELECT true, 'dismiss:' || pd.id::text, pd.created_at, 'protokol_dismiss'::text
  FROM protokol_dismiss pd
  WHERE pd.hayvan_id = p_hayvan_id
    AND pd.vaccine_id = p_vaccine_id
    AND pd.protokol IN ('BUZAGI_ASI_PROTOKOL','YILLIK_ASI_PROTOKOL','DOGUM_SONRASI_ASI_PROTOKOL')
  LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- Bulunamadı
  RETURN QUERY SELECT false, NULL::text, NULL::timestamptz, NULL::text;
END;
$$;
```

### 5.4 Performans Index'leri

```sql
-- Mevcut index'ler korunur
-- Yeni index'ler:
CREATE INDEX IF NOT EXISTS idx_vaccination_log_animal_vaccine
  ON vaccination_log(animal_id, vaccine_id, vaccination_date DESC);

CREATE INDEX IF NOT EXISTS idx_vaccine_components_vaccine
  ON vaccine_components(vaccine_id);

CREATE INDEX IF NOT EXISTS idx_asi_tekrar_kurallari_vaccine
  ON asi_tekrar_kurallari(vaccine_id);

CREATE INDEX IF NOT EXISTS idx_vaccination_schedule_target_type
  ON vaccination_schedule(target_type, timing_type)
  WHERE timing_type IN ('yas', 'dogum_sonra');
```

### 5.5 `protokol_eksik_tara` Çıktısı (Genişletilmiş)

```jsonb
[
  // Mevcut 3 bölüm (A, B, C)
  {"hayvan_id": "abc", "protokol": "DOGUM_PROTOKOL", "adim": "2. Gün PG", "durum": "eksik", "etken_kod": "PG"},
  
  // Yeni bölüm D: Buzağı aşı
  {"hayvan_id": "H000152", "protokol": "BUZAGI_ASI_PROTOKOL", "adim": "💉 BVD (60. gün)", 
   "vaccine_id": "uuid-1", "etken_kod": null, "hedef_tarih": "2026-08-12", "durum": "eksik"},
  
  // Yeni bölüm E: Yetişkin yıllık
  {"hayvan_id": "4521", "protokol": "YILLIK_ASI_PROTOKOL", "adim": "💉 Coglavax (yıllık tekrar)",
   "vaccine_id": "uuid-2", "etken_kod": null, "hedef_tarih": "2025-06-12", "durum": "koruma_gecmis"},
  
  // Yeni bölüm F: Doğum sonrası inek
  {"hayvan_id": "anne-1", "protokol": "DOGUM_SONRASI_ASI_PROTOKOL", "adim": "💉 Leptospirosis (30. gün)",
   "vaccine_id": "uuid-3", "etken_kod": null, "hedef_tarih": "2026-07-10", "durum": "yaklasan"}
]
```

**`etken_kod` aşılar için NULL** — bunun yerine `vaccine_id` kullanılır. Mevcut dismiss modeli `etken_kod` bekliyor, bu yüzden yeni `vaccine_id` kolonu eklendi.

---

## 6. Migration Yol Haritası

### 6.1 7 Migration Dosyası (Önerilen Sıra)

| # | Dosya | İçerik | Bağımlılık | Risk |
|---|-------|--------|-----------|------|
| 1 | `2026061201_asi_tekrar_kurallari.sql` | Yeni tablo + seed (12 aşı × 2-3 kural = ~24 satır) | vaccines | Düşük |
| 2 | `2026061202_vaccine_components.sql` | Yeni tablo + seed (Coglavax 3, Vac-Sules 4 = 7 satır) | vaccines | Düşük |
| 3 | `2026061203_gorev_log_vaccine_id.sql` | ALTER TABLE + 2 yeni index | vaccines | Düşük |
| 4 | `2026061204_vaccination_schedule_seed_genislet.sql` | E.coli/Rota/Corona/BRSV/Piogen/Clostridium + yetişkin Şarbon/BVD/IBR yıllık = +10 satır | yok | Düşük |
| 5 | `2026061205_buzagi_asi_gorev_olustur_rpc.sql` | Yeni RPC + `dogum_kaydet` entegrasyonu (migration #6'daki güncelleme) | 1, 2, 3, 4 | **ORTA** |
| 6 | `2026061206_yillik_asi_kontrol_rpc.sql` | Yeni RPC + pg_cron job (Pazartesi 03:00) + `gecmise_asi_ekle` RPC | 1, 2, 3 | Düşük |
| 7 | `2026061207_asi_protokol_tara_rpc.sql` | `_asi_eksik_mi` helper + `asi_protokol_tara` (dry-run) + `protokol_eksik_tara` D/E/F bölümleri | 1, 2, 3, 4, 5, 6 | **ORTA** |

### 6.2 Frontend (3 dosya)

| Dosya | Değişiklik | Tahmini |
|-------|-----------|---------|
| `index.html` | 2 yeni sekme (Aşı Tanımları, Aşı Durumu) + 2 yeni modal (Geçmişe Aşı Ekle) + Dashboard bandı | 1-2 saat |
| `js/ui.js` | `loadAsiDurumu()`, `loadAsiTanimlar()`, `renderTask()` güncelleme, `dashboard` bandı | 2-3 saat |
| `js/forms.js` | `submitVaccination()` güncelleme (takip aşısı checkbox), `saveGecmisAsi()` | 1 saat |
| `js/api.js` | 4 yeni RPC tipi (TABLES, RPC_TABLES) | 0.5 saat |

### 6.3 pg_cron Scheduler

```sql
-- Migration #6'da eklenecek:

-- 1. Yıllık aşı kontrol (haftalık Pazartesi 03:00)
SELECT cron.schedule(
  'yillik-asi-kontrol',
  '0 3 * * 1',
  $$SELECT public.yillik_asi_gorev_kontrol()$$
);
```

Mevcut cron job'lar:
- `stale-tohumlama-gorev-temizle` (4 saatte bir) — korunur
- Yeni: `yillik-asi-kontrol` (haftalık)

### 6.4 Geriye Uyumluluk

- ✅ Mevcut `add_vaccination` değişmez, `asi_tekrar_kurallari` tetiklemez (sadece ASI_RAPEL oluşturur)
- ✅ Mevcut `protokol_eksik_tara` A/B/C bölümleri korunur, D/E/F eklenir
- ✅ Mevcut `protokol_dismiss` etken_kod bazlı çalışmaya devam eder, yeni vaccine_id kolonu eklenir (NULL olanlar etken_kod kullanır)
- ✅ Mevcut `dogum_kaydet` davranışı değişmez, sadece sonuna `buzagi_asi_gorev_olustur(buzagi_id)` çağrısı eklenir
- ✅ Mevcut `vaccination_log` kolonları korunur, yeni kolon eklenmez (sadece yeni tablo ilişkileri)

---

## 7. Test Senaryoları (10 adet)

| # | Senaryo | Adımlar | Beklenen |
|---|---------|---------|----------|
| 1 | **Karma aşı** | Coglavax (3 hastalık) → `add_vaccination` → `vaccination_log` INSERT | 1 log, 3 disease koruması (vaccine_components) |
| 2 | **Buzağı ilk aşı + rapel** | Doğum → `buzagi_asi_gorev_olustur` → 2-3 gorev → 1. doz uygulandığında 2. doz görevi tetiklenir | Toplam 2-3 gorev, sıralı |
| 3 | **Yetişkin ilk kez aşı** | `gecmise_asi_ekle` (tarih=bugün-30, vaccine=Coglavax) | `next_due_date=bugün+335`, `YILLIK_ASI` gorev INSERT |
| 4 | **Yetişkin yıllık tekrar** | `yillik_asi_kontrol` → son aşı + 365 ≤ bugün+30 → gorev INSERT | Gorev oluşur, idempotent (2. kez çalışmaz) |
| 5 | **protokol_eksik_tara D** | Buzağı 70 günlük, BVD 1. doz uygulanmamış | `{protokol: 'BUZAGI_ASI_PROTOKOL', durum: 'eksik'}` |
| 6 | **protokol_eksik_tara E** | İnek 4521, son Şarbon 14 ay önce | `{protokol: 'YILLIK_ASI_PROTOKOL', durum: 'eksik'}` |
| 7 | **Dismiss akışı** | Eksik uyarıya tıkla → "Ertele" → `protokol_dismiss` INSERT → bir sonraki scan'de görünmez | Dismiss'lı hayvan bir daha çıkmaz |
| 8 | **Dry-run** | `asi_protokol_tara(true)` → 12 önerilen görev, hiç INSERT yok | Sadece JSON döner, DB değişmez |
| 9 | **Tanimlar UI** | Coglavax kuralını değiştir (28 → 35 gün) → kaydet → bir sonraki scan yeni kuralı kullanır | Yeni kural aktif |
| 10 | **Geriye uyumluluk** | Eski `add_vaccination` çağrısı (migration #5'ten önce) hâlâ çalışıyor | Yeni `asi_tekrar_kurallari` tetiklenmiyor, sadece mevcut ASI_RAPEL |

### 7.1 Manuel Test Adımları (Senaryo 2 detay)

```
1. dogum_kaydet RPC çağır (anne_id, tarih=bugün, kupe=H999, cins=Holstein, tip=normal, kg=40, baba=null, hekim_id=null)
2. Kontrol: gorev_log'da H999 için BUZAGI_ASI tipi 2-3 satır
   - "BVD (60. gün)" → hedef = bugün + 60
   - "BVD (120. gün)" → hedef = bugün + 120
   - "Şarbon (180. gün)" → hedef = bugün + 180
3. Kontrol: protokol_instance'da ASITAKVIMI/BUZAGI instance
4. 60 gün simüle et (test ortamı) veya mevcut buzağıyı bul
5. add_vaccination(H999, BVD, bugün) çağır
6. Kontrol: gorev_log'da BVD 1. doz tamamlandı=true, kapatan_ref='vaccination_log:...'
7. Kontrol: BVD 2. doz görevi hâlâ tamamlanmamış (120. gün hedefli)
8. (Opsiyonel) 120. gün geldiğinde add_vaccination → 2. doz uygulandı → YILLIK_ASI oluşur
```

### 7.2 Performans Testi

```sql
-- protokol_eksik_tara çağrısı öncesi EXPLAIN
EXPLAIN ANALYZE
SELECT * FROM public.protokol_eksik_tara();

-- Beklenen: 6 bölüm × 5 arama yeri = O(30N) ama index'lerle < 500ms (N=500 aktif hayvan için)
```

---

## 8. Açık Sorular (Implementasyon Öncesi Netleşmeli)

1. **Karma aşı UI'ında disease_code seçimi:** Master liste (dropdown) mı, free-text mi? → **Öneri: Dropdown** (sistem genelinde tutarlılık)
2. **`gecmise_asi_ekle` tarih üst sınırı:** Sadece bugün mü, geçmişe X ay mı? → **Öneri: Sadece bugün** (eski tarihli aşı için ayrı senaryo)
3. **`protokol_eksik_tara` performansı:** 6 bölüm + 5 arama yeri = O(30N). Index'ler yeterli mi? → İlk test'te ölçülür
4. **Tanimlar UI'ı admin-only mi?** settings tablosuna `asi_yonetimi_enabled` eklensin mi? → **Öneri: Başlangıçta tüm kullanıcılar** (aşı ekleme yetkisi olan herkes)
5. **Dry-run onay mekanizması:** Settings'ten kapatılabilir mi? → **Öneri: Başlangıçta zorunlu**, ayar sonra eklenebilir
6. **`vaccination_dismiss` (mevcut) ile `protokol_dismiss` (yeni) birlikte mi?** Mevcut `vaccination_dismiss` sadece aşı tek seferlik erteleme, `protokol_dismiss` periyodik taramayı dismiss eder → **Öneri: İkisi birlikte çalışsın**
7. **`is_combo` filtresi** vaccines kolonunda yeterli mi yoksa `vaccine_components` sayısıyla mı hesaplanmalı? → **Öneri: Manuel** (UI'dan seçilir), çünkü master data yönetimi

---

## 9. Sonraki Adımlar

### 9.1 Bu Tasarım Onaylandıktan Sonra

1. ✅ **Bu dosyayı commit et** (branch: `feature/asilama-tam-mimari`)
2. ➡️ **`/skill:writing-plans` skill'ini çağır** — Implementation plan oluştur
3. ➡️ **`/skill:using-git-worktrees` skill'ini çağır** — İzole workspace (büyük iş)
4. ➡️ **Spec/task dosyaları yaz** → `blackboard/specs/spec-asilama-tam-mimari.md`
5. ➡️ **Implementation başla** (TDD pattern'i ile)

### 9.2 Karar Gereken

| Karar | Seçenek | Önerilen |
|-------|--------|----------|
| Worktree kullan | `using-git-worktrees` ile izole workspace | EVET (büyük iş, 14-18 saat) |
| Spec tek parça mı | 1 büyük spec mi, 7 küçük spec mi? | 1 büyük (atomik özellik) |
| Goose ile mi yapalım | `recipes/egesut` ile otomatik worker | Kısmen — DB migration + RPC, JS elle |
| Test stratejisi | TDD mi, integration test mi? | Önce migration + manual test, sonra JS test |

---

## 10. Referanslar

- **Araştırma:** `docs/research/2026-06-12-asi-sistemi-mevcut-durum-ve-dilek.md` (887 satır)
- **Mevcut aşılama modülü:** `supabase/migrations/20260331000032_vaccination_module.sql`
- **İleri gebe görev:** `20260509000001-4`, `20260605000008`
- **Protokol scanner:** `20260603000004`, `20260603000005`
- **Doğum kaydı:** `20260605000006`
- **Dinleme trigger mimarisi:** `20260603000003` (BUG-064)
- **Aşılama UI spec:** `asilama-spec.md` (Sprint VAC-01, 2026-04-09)
- **Refactor dersleri:** `docs/agent-lessons-egesut.md`, memory `project_egesut_hekim_karti_2026-05-11.md`

---

**Hazırlayan:** Pi agent (MiniMax-M3) + Kullanıcı brainstorming'i
**Tarih:** 2026-06-12
**Durum:** Brainstorm TAMAMLANDI, implementation plan yazımı bekleniyor
