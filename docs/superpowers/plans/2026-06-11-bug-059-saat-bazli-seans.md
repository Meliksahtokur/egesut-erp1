# BUG-059 Saat Bazlı Tedavi Seans — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** EgeSüt ERP tedavi modülünü "1 günde N seans (saat+ilaç+doz+yol)" modeline geçirmek, reçete değişikliklerini reaktif yansıtmak ve mevcut 4 aktif vakayı etkilemeden geriye uyumlu çalışmak.

**Architecture:**
- Yeni tablo: `treatment_day_uygulamalar` (her seans = 1 satır)
- `treatment_days.seans_sayisi` kolonu (1=eski, N=yeni) ile dual-path
- `drug_administrations.seans_admin_id` FK ile K5 bağlantısı
- 4 yeni RPC + 1 güncellenen RPC, hepsi Supabase SECURITY DEFINER
- DRY: `recete_guncelle` → `add_treatment_day_with_sessions` (p_existing_day_id)
- Idempotent: `treatment_day_tamamla` zaten-tamamlanmışsa noop

**Tech Stack:** Supabase PostgreSQL + RPC, Vanilla JS (no bundler), GitHub Pages deploy.

**Spec:** `docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md` (1065 satır, REVIEW v4 ONAY)

---

## 🛠️ Araç Kullanım Haritası (tools-bank + repomix + ast-grep)

Bu plan her Fazda hangi aracın neden kullanılacağını gösterir. Mühendis aracı bilmiyor diye açıklıyoruz.

| Faz | Araç | Ne Zaman | Neden |
|---|---|---|---|
| **0** | `memory_search("BUG-059 RPC ground truth")` | Faz 0 başında | Önceki oturum notları + RPC imzaları |
| **0** | `supabase_query(information_schema.columns)` | ground truth yerine | Live DB şeması her zaman doğru, migration dosyası eski olabilir |
| **0** | `semantic_search("tedavi seans geriye uyumluluk")` | Pato 12 kontrolü | Geçmiş bug'lardan aynı kalıbı yakala |
| **1** | `supabase_migrate(sql)` | Migration çalıştırma | DDL için tek yetkili yol (anon key ile CREATE TABLE yapılamaz) |
| **1** | `supabase_query(information_schema.columns)` | Migration sonrası verify | Kolon gerçekten eklendi mi? |
| **2** | `supabase_rpc("function_name")` | RPC test | psql yok, canlı çağrı ile test |
| **2** | `gitnexus_impact("add_treatment_day_with_sessions")` | Faz 2 başında | Blast radius — eski kod kırılır mı? |
| **2** | `gitnexus_detect_changes(scope=staged)` | Commit öncesi | Beklenen semboller mi değişti? |
| **3** | `repomix.pack_codebase` (ground truth diff için) | Opsiyonel | Çok büyük dosya, repomix ile sıkıştır |
| **3** | `ast_grep_search("add_treatment_day($$$)", lang=javascript)` | Frontend çağrı taraması | Eski RPC'yi çağıran frontend yerleri |
| **4** | `sonar_issues(types=BUG)` | Deploy sonrası | Yeni bug var mı? |
| **5** | `ast_grep_search("renderTask\|toggleSub", lang=javascript)` | UI değişikliği öncesi | Mevcut pattern'i gör, dokunma |
| **6** | `supabase_rpc` (senaryo testleri) | Her senaryo | Live DB üzerinde end-to-end |
| **7** | `memory_add(category=code_change)` | Session sonu | Spec→plan→impl döngüsünü kaydet |
| **7** | `todo_write` | Faz 7 sonu | Tüm checklist kapatıldı |

**Hata durumunda:**
- Migration patladı → `supabase_query(information_schema)` ile parça parça kontrol et
- RPC syntax hatası → `supabase_migrate` ayrı ayrı DROP+CREATE ile parçala
- Frontend patladı → `gitnexus_context(symbol=renderTask)` ile callers gör
- Genel debug → `gitnexus_query("tedavi seans")` ile execution flow bul

---

## 📂 Dosya Yapısı (Faz Bazlı)

### Yeni Dosyalar (Create)
- `supabase/migrations/20260611000001_bug059_treatment_sessions.sql` — Schema + 4 yeni RPC + 1 güncelleme
- `supabase/migrations/20260611000002_bug059_ground_truth_sync.sql` — Ground truth'a aynı kodu ekle (Pato 12)

### Değişen Dosyalar (Modify)
- `supabase/migrations/99999999999999_ground_truth.sql` — Canonical referans güncelle
- `js/api.js` — `seans_tamamla`, `recete_guncelle`, `close_case_with_remaining` RPC helper'ları + `add_treatment_day_with_sessions`
- `js/ui.js` — Tedavi modal accordion + renderTask saat rozeti + vaka modal plan accordion
- `docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md` — Implement edildi notu (opsiyonel)

### Silinen/Dokunulmayan Dosyalar
- `js/forms.js` — Sadece yeni RPC çağrıları eklenecek, mevcut mantık korunur
- `js/state.js`, `js/config.js` — Dokunulmaz
- `index.html` — Dokunulmaz (PWA, CDN-only)

---

## Faz 0: Pre-Check (Pato 12 — Spec ile Reality Ayrışması)

> **Neden:** Gecmis bug'lar spec yazarken ground truth'tan birebir kopyalanmadigi icin cikti (K1: `stok_hareket.id` text ama spec'te uuid yazdik). Bu Faz onler.

- [ ] **Step 0.1: Canonical ground truth'u oku (ARA MIGRATION DEGIL)**

```bash
file_read("supabase/migrations/99999999999999_ground_truth.sql")
```

Sadece su bolumleri oku:
- `treatment_days` tablo tanimi
- `drug_administrations` tablo tanimi
- `gorev_log` tablo tanimi
- `stok_hareket` tablo tanimi
- `stok` tablo tanimi
- `add_treatment_day` RPC (L3162-3299)
- `treatment_day_tamamla` RPC (L3300-3434)

Ara migration dosyalari (`*_fix.sql`, `*_revize.sql`, `*_v2.sql`) **YANLIS referanstir**.

- [ ] **Step 0.2: Live DB semasini dogrula (ground truth drift kontrolu)**

Araclar: `supabase_query` + `semantic_search`

```sql
-- 1. Tedavi ile ilgili tablolar
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name IN (
  'treatment_days', 'drug_administrations', 'gorev_log',
  'stok_hareket', 'stok', 'drug_products', 'cases', 'islem_log'
) ORDER BY table_name;

-- 2. Tedavi gunu ve seansi icin kritik kolonlar
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name IN (
  'treatment_days', 'drug_administrations', 'gorev_log', 'stok_hareket'
) AND column_name IN (
  'id', 'planned_time', 'seans_sayisi', 'seans_admin_id',
  'uygulama_tamamlandi_at', 'uygulanmadi', 'stok_hareket_ref',
  'stok_id', 'iptal', 'parent_id', 'aciklama'
) ORDER BY table_name, column_name;
```

Beklenen kontroller (drift = ground truth yanlis ise):
- `treatment_days.id` -> `uuid`
- `drug_administrations.id` -> `uuid`
- `stok_hareket.id` -> **`text`** (K1 hata kaynagi, `gen_random_uuid()::text` veya `text` UUID sakliyor)
- `gorev_log.id` -> **`text`** ama UUID string saklar (INSERT: `gen_random_uuid()::text`)
- `gorev_log.parent_id` -> `text` (UUID string olarak)
- `drug_administrations.seans_admin_id` -> **KOLON YOK OLMALI** (migration'da eklenecek)

Drift bulunursa -> spec'te `stok_hareket.id`'ye `REFERENCES` olan her yerde **`text`** kullan. `cases.animal_id` da `text` olabilir, kontrol et.

- [ ] **Step 0.3: Gecmis bug'lari tara (Pato 12 — ayni kalip var mi?)**

```python
semantic_search("tedavi seans saat geriye uyumluluk schema drift", limit=5)
memory_search("BUG-059 K1 K2 K3 schema drift", category="critical_rules", limit=5)
```

Hedef: K1, K2, K3 tarzi hatalari gecmiste de yaptik mi?

- [ ] **Step 0.4: Mevcut 4 vakayi say (geriye uyumluluk hedefi)**

```sql
SELECT c.id, c.animal_id, c.status, COUNT(td.id) AS day_count
FROM public.cases c
LEFT JOIN public.treatment_days td ON td.case_id = c.id
WHERE c.status = 'active'
GROUP BY c.id, c.animal_id, c.status
ORDER BY c.id;
```

Beklenen: 4 satir (vaka 140, 5, 7, 9). Bunlar degismemeli.

- [ ] **Step 0.5: tools-bank memory'den RPC notlarini cek**

```python
memory_search("add_treatment_day_with_sessions recete_guncelle", category="rpc_reference", limit=5)
```

- [ ] **Step 0.6: GitNexus blast radius**

```python
gitnexus_impact(target="add_treatment_day", direction="upstream", depth=2)
```

Frontend'de `add_treatment_day` cagrilan yerleri gor. Yeni RPC (`add_treatment_day_with_sessions`) **onlarin yerine gececek mi, yoksa yan yana mi?** Spec karar 4-C: yan yana (geriye uyumlu).

- [ ] **Step 0.7: Spec onay checkpoint**

Kullaniciya onay sor:

```
"FAZ 0 TAMAM. Bulgular:
- [varsa drift: ornek cases.animal_id = text bekleniyor, DB'de text OK]
- [varsa eski cagri yerleri: 4 yerde add_treatment_day kullaniliyor]
- [varsa hafiza notlari: ...]

Spec dogrulandi, migration'a geciyorum. Onay?"
```

"Onayliyorum" gelmeden Faz 1'e gecme.

---


## Faz 1: Schema Migration (DDL)

> **Hedef:** 1 yeni tablo + 3 ALTER kolonu + 5 partial index. Migration idempotent (IF NOT EXISTS / IF EXISTS).

- [ ] **Step 1.1: Migration dosyasini olustur**

```bash
touch supabase/migrations/20260611000001_bug059_treatment_sessions.sql
```

- [ ] **Step 1.2: SQL'i dosyaya yaz (Parcali — write araci buyuk dosyada parse hatasi verir)**

**Parca 1: Header + CREATE TABLE + CREATE INDEX (~80 satir)**

```sql
-- 2026-06-11: BUG-059 — Saat bazli tedavi seans destegi
-- Yeni tablo: treatment_day_uygulamalar (seans bazli detay)
-- Eski tablolar: kolon ekleme (geriye uyumlu)
-- Spec: docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md

BEGIN;

-- 1. YENI TABLO: treatment_day_uygulamalar
CREATE TABLE IF NOT EXISTS public.treatment_day_uygulamalar (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id            uuid NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  case_id                     uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,

  -- SEANS BILGISI
  sira_no                     smallint NOT NULL CHECK (sira_no > 0),
  planned_time                time NOT NULL,
  planned_date                date NOT NULL,

  -- ILAC
  stok_id                     text REFERENCES public.stok(id),
  drug_product_id             uuid REFERENCES public.drug_products(id),
  dose                        numeric NOT NULL CHECK (dose > 0),
  unit                        text NOT NULL,
  route                       text CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin')),

  -- DONE STATE
  uygulama_tamamlandi_at      timestamptz,
  uygulayan                   text,
  uygulama_notu               text,
  uygulanmadi                 boolean DEFAULT false,
  iptal_nedeni                text,

  -- STOK LEDGER REFERANSI (iptalde kullanilacak) — K1: text FK
  stok_hareket_ref            text REFERENCES public.stok_hareket(id) ON DELETE SET NULL,

  -- AUDIT
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),

  UNIQUE(treatment_day_id, sira_no),
  -- O-v3-1: 1 seans = 1 ilac, farkli ilaclar icin 5dk aralik ile saat girilir
  UNIQUE(treatment_day_id, planned_time)
);

CREATE INDEX IF NOT EXISTS tdu_day_id_idx    ON public.treatment_day_uygulamalar(treatment_day_id);
CREATE INDEX IF NOT EXISTS tdu_case_date_idx ON public.treatment_day_uygulamalar(case_id, planned_date);
CREATE INDEX IF NOT EXISTS tdu_open_idx      ON public.treatment_day_uygulamalar(case_id)
  WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;
CREATE INDEX IF NOT EXISTS tdu_late_idx      ON public.treatment_day_uygulamalar(planned_date, planned_time)
  WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;

COMMENT ON TABLE public.treatment_day_uygulamalar
  IS 'Tedavi gunu alt seanslari. Saat + ilac + doz + yol, gercek zamanli zincir mimarisi. NULL seans = eski tek-seans davranis.';
COMMENT ON COLUMN public.treatment_day_uygulamalar.sira_no
  IS 'Gun icinde 1, 2, 3... sirasi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.planned_time
  IS '08:00, 16:00, 24:00 gibi gercek saat';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulama_tamamlandi_at
  IS 'NULL = henuz yapilmadi, now() = yapildi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulanmadi
  IS 'true = "yapilmadi, stok iade"';
COMMENT ON COLUMN public.treatment_day_uygulamalar.stok_hareket_ref
  IS 'K1: stok_hareket.id text, FK text';
```

**Parca 2: ALTER kolonlari (~35 satir)**

```sql
-- 2. MEVCUT treatment_days EK KOLON
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS seans_sayisi smallint DEFAULT 1;
COMMENT ON COLUMN public.treatment_days.seans_sayisi
  IS 'Bu gündeki planlanan seans sayisi (1 = eski davranis, N = yeni cok seans)';

-- 3. MEVCUT gorev_log EK KOLONLAR
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
    REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.gorev_log.seans_admin_id
  IS 'Bu gorevi hangi seans tetikledi? NULL = gun seviyesi (eski davranis)';

ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS hedef_saat time;
COMMENT ON COLUMN public.gorev_log.hedef_saat
  IS 'Seansin planlanan saati (sadece TEDAVI_SEANS icin)';

-- 4. K5: drug_administrations'a seans baglantisi
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
    REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.drug_administrations.seans_admin_id
  IS 'Bu ilac hangi seansa ait? NULL = eski tek-seans akis (geriye uyumlu)';

CREATE INDEX IF NOT EXISTS da_seans_admin_id_idx
  ON public.drug_administrations(seans_admin_id) WHERE seans_admin_id IS NOT NULL;

COMMIT;
```

**Yazim prosedurü** (write araci buyuk dosyada parse hatasi):

```bash
# Parca 1 (~80 satir) -> write ile tek seferde
# Parca 2 (~35 satir) -> shell append ile ekle veya ayri write
# Toplam ~150 satir, sinirin altinda ama FK + index cok satir kapliyor
# Eger yine parse hatasi gelirse 3 parcaya bol
```

- [ ] **Step 1.3: Dosya butunlugunu dogrula**

```bash
wc -l supabase/migrations/20260611000001_bug059_treatment_sessions.sql
head -5 supabase/migrations/20260611000001_bug059_treatment_sessions.sql
tail -3 supabase/migrations/20260611000001_bug059_treatment_sessions.sql
grep -c "COMMIT;" supabase/migrations/20260611000001_bug059_treatment_sessions.sql
```

Beklenen: ~120-150 satir, basta tarihli yorum, sonda `COMMIT;` (1 adet).

- [ ] **Step 1.4: Migration'i canlida calistir**

Arac: `supabase_migrate` (DDL icin tek yetkili yol — anon key yapamaz)

```python
supabase_migrate(sql=open('supabase/migrations/20260611000001_bug059_treatment_sessions.sql').read())
```

Beklenen: Basari mesaji, hata yok. Hata varsa:
- "relation already exists" -> CREATE TABLE IF NOT EXISTS zaten var, sorun yok
- "column already exists" -> ADD COLUMN IF NOT EXISTS zaten var, sorun yok
- "permission denied" -> Management API token suresi dolmus, yenile

- [ ] **Step 1.5: Semayi dogrula (live DB drift kontrolu)**

Arac: `supabase_query`

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND (
  (table_name = 'treatment_day_uygulamalar' AND column_name IN ('id', 'sira_no', 'planned_time', 'stok_hareket_ref'))
  OR (table_name = 'treatment_days' AND column_name = 'seans_sayisi')
  OR (table_name = 'gorev_log' AND column_name IN ('seans_admin_id', 'hedef_saat'))
  OR (table_name = 'drug_administrations' AND column_name = 'seans_admin_id')
) ORDER BY table_name, column_name;
```

Beklenen: 8 satir (1 yeni tablo icin 4 kolon, 4 ALTER kolonu).

- [ ] **Step 1.6: Index kontrolu**

```sql
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN (
  'treatment_day_uygulamalar', 'drug_administrations'
) AND indexname IN (
  'tdu_day_id_idx', 'tdu_case_date_idx', 'tdu_open_idx', 'tdu_late_idx', 'da_seans_admin_id_idx'
) ORDER BY indexname;
```

Beklenen: 5 satir.

- [ ] **Step 1.7: UNIQUE constraint kontrolu (1 seans = 1 ilac)**

```sql
SELECT conname, contype FROM pg_constraint
WHERE conrelid = 'public.treatment_day_uygulamalar'::regclass
  AND contype = 'u'
ORDER BY conname;
```

Beklenen: 2 satir (`treatment_day_uygulamalar_treatment_day_id_sira_no_key`, `treatment_day_uygulamalar_treatment_day_id_planned_time_key`).

- [ ] **Step 1.8: Geriye uyumluluk smoke test**

```sql
-- Mevcut 4 vakayi oku, seans_sayisi default 1 olmali
SELECT id, seans_sayisi, planned_time
FROM public.treatment_days
ORDER BY id LIMIT 5;
```

Beklenen: Tum satirlar `seans_sayisi=1` (default migration ile doldu).

- [ ] **Step 1.9: Commit (YAPMA — D1 fix)**

> **D1 fix:** DDL ve RPC'ler AYNI migration dosyasinda (Faz 1 + Faz 2 birlikte yazildi). Cift commit YAPMA, sadece Faz 2 sonunda TEK commit at. Step 2.13'e bak.

---


## Faz 2: RPC'ler (4 Yeni + 1 Guncelleme)

> **Hedef:** 5 RPC'yi `20260611000001_bug059_treatment_sessions.sql` dosyasina ekle (ayni migration), her birini ayri ayri calistir, canli test et.

> **Strateji:** Spec doc'taki SQL'i birebir kopyala (zaten review v4 onayli). Spec'in tam haline bak: `docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md` L300-1000.

- [ ] **Step 2.0: GitNexus blast radius (RPC 1 oncesi)**

```python
gitnexus_impact(target="add_treatment_day", direction="upstream", depth=2)
```

Hedef: Eski `add_treatment_day` cagrilan frontend yerleri. Yeni RPC yan yana (karar 4-C), mevcut yerler bozulmamali.

- [ ] **Step 2.1: RPC 1 — `add_treatment_day_with_sessions` (YENI)**

Spec L300-575. Ayni migration dosyasina ekle, `COMMIT;` oncesine.

SQL baslica:
- 4 parametre: `p_case_id uuid, p_date date, p_sessions jsonb DEFAULT NULL, p_existing_day_id uuid DEFAULT NULL`
- `RETURNS jsonb` (K4: RETURN degil)
- DECLARE: `v_day_id, v_gorev_id, v_prev_gorev_id, v_day_no, v_case, v_gecmis, v_session, v_seans_sayisi, v_admin_ids, v_admin_id, v_first_time, v_sira_no, v_is_update`
- v_is_update := p_existing_day_id IS NOT NULL
- INSERT veya UPDATE path (mevcut gun ise)
- N seans dongusu: INSERT treatment_day_uygulamalar + INSERT drug_administrations + INSERT stok_hareket ATOMIK (K2/K3 duzeltme)
- Audit: CASE WHEN v_is_update THEN 'RECETE_GUNCELLENDI' ELSE 'TEDAVI_GUN_EKLENDI'

> **Yazim notu:** Spec'te bu RPC ~275 satir. write aracina tek seferde VERME. Parcali yaz:
> - Parca A: Header + DECLARE + v_is_update logic (L300-380)
> - Parca B: INSERT/UPDATE path (L380-470)
> - Parca C: Seans dongusu (L470-540)
> - Parca D: Audit + RETURN + GRANT (L540-580)

- [ ] **Step 2.2: RPC 2 — `seans_tamamla` (YENI, race guard)**

Spec L585-690. Tek seans done/iptal + zincirleme gun done.

SQL baslica:
- 3 parametre: `p_seans_admin_id uuid, p_uygulanmadi boolean DEFAULT false, p_not text DEFAULT NULL`
- SELECT FOR UPDATE ile satir kilitle (race condition guard)
- IF p_uygulanmadi: seans + drug_admins + stok_hareket atomik (Y2)
- ELSE: UPDATE WHERE guard ile done
- Tum seanslar done mi? -> gun tamamla
- Audit: 'TEDAVI_SEANS_TAMAM' veya 'TEDAVI_SEANS_IPTAL'

> **Yazim notu:** Spec'te ~100 satir. Tek write ile yazilabilir.

- [ ] **Step 2.3: RPC 3 — `recete_guncelle` (YENI, DRY delegasyon)**

Spec L695-780. Henuz acilmamis gunleri toplu guncelle.

SQL baslica:
- 2 parametre: `p_case_id uuid, p_yeni_plan jsonb`
- FOR v_day_plan IN SELECT * FROM jsonb_array_elements(p_yeni_plan) LOOP
- KISMEN_ACILMIS GUN DOKUNULMAZ (Soru 4-C): en az 1 seansi done ise ATLA
- 3 durum:
  - v_day_id IS NULL -> add_treatment_day_with_sessions (yeni gun)
  - v_day_id IS NOT NULL AND v_tamam = false -> add_treatment_day_with_sessions(p_existing_day_id=v_day_id) (K-NEW-1 C cozumu)
  - v_day_id IS NOT NULL AND v_tamam = true -> ATLA (zaten bitmis)
- RETURN guncellenen seans sayisi

> **D-v3-3 fix:** Bu RPC'de `v_session, v_admin_id, v_sira_no, v_first_time` gibi DRY sonrasi kullanilmayan degiskenler OLMAMALI (runtime crash L704).

- [ ] **Step 2.4: RPC 4 — `close_case_with_remaining` (YENI)**

Spec L785-840. Vaka erken kapatildiginda kalan seanslari "yapilmadi" isaretle + stok iade.

SQL baslica:
- 2 parametre: `p_case_id uuid, p_not text DEFAULT NULL`
- `RETURNS jsonb` (K4 fix)
- 7 adim:
  1. Stok iade (drug_admins INSERT aninda dusmustu, geri al)
  2. treatment_day_uygulamalar: uygulanmadi=true + iptal_nedeni (Y3)
  3. drug_admins da senkron (Y2 pattern + Y-NEW-2 duzeltme)
  4. treatment_days tamamlandi
  5. gorev_log kalan acik gorevler done
  6. cases.status = 'closed'
  7. Audit 'CASE_CLOSED_EARLY'

- [ ] **Step 2.5: RPC 5 — `treatment_day_tamamla` (GUNCELLEME)**

Spec L845-1000. Mevcut RPC geriye uyumlu kalir, davranis seans_sayisi > 1 ise genisler.

SQL baslica:
- Mevcut imza korunur: `p_day_id uuid, p_not text, p_uygulanmadi_ids uuid[]`
- IDEMPOTENT: `IF v_day.tamamlandi THEN RETURN ok=true` (self-review fix)
- Onceki gun tamamlanmali guard
- YENI: seans_sayisi > 1 ise "tum seanslar done/iptal" kontrolu
- FOREACH v_admin_id: ONCE drug_admins, SONRA treatment_day_uygulamalar, SONRA stok_hareket_ref
- Geriye uyumluluk: `seans_sayisi=1` vakalari eski akis (sadece drug_admins uzerinden)
- v_admin_id = seans.id oldugunda K5 FK ile bagli drug_admins bulunur
- Y-v3-1 fix: `stok_hareket_ref` direkt kullan, eski path fallback

- [ ] **Step 2.6: Tek seferde canli deploy**

Arac: `supabase_migrate` (RPC CREATE FUNCTION icin de gecerli)

```python
supabase_migrate(sql=open('supabase/migrations/20260611000001_bug059_treatment_sessions.sql').read())
```

Beklenen: 5 RPC olustu, hata yok.

Hata durumunda:
- "function already exists" -> DROP FUNCTION IF EXISTS zaten var, sorun yok (migration idempotent)
- "syntax error" -> spec'teki SQL birebir alinmali, elle duzeltme YAPMA, spec'e don
- "permission denied for language c" -> SECURITY DEFINER sorunu, supabase_migrate bunu yapabilmeli

- [ ] **Step 2.7: RPC listesini dogrula**

```sql
SELECT proname, prosecdef
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'add_treatment_day_with_sessions',
    'seans_tamamla',
    'recete_guncelle',
    'close_case_with_remaining',
    'treatment_day_tamamla'
  )
ORDER BY proname;
```

Beklenen: 5 satir, `prosecdef=true` (hepsi SECURITY DEFINER).

- [ ] **Step 2.8: RPC imza kontrolu (parametre sayisi ve tipleri)**

```sql
SELECT p.proname,
  pg_get_function_arguments(p.oid) AS args,
  pg_get_function_result(p.oid) AS returns
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname IN (
    'add_treatment_day_with_sessions',
    'seans_tamamla',
    'recete_guncelle',
    'close_case_with_remaining'
  )
ORDER BY p.proname;
```

Beklenen:
- `add_treatment_day_with_sessions(uuid, date, jsonb, uuid)` -> `jsonb`
- `seans_tamamla(uuid, boolean, text)` -> `jsonb`
- `recete_guncelle(uuid, jsonb)` -> `jsonb`
- `close_case_with_remaining(uuid, text)` -> `jsonb`

- [ ] **Step 2.9: Canli RPC smoke test (RPC 1) — OPSIYONEL**

> **Y1 notu:** Canli smoke test zorunlu degil (kullanici canlida test eder). Eger calistirilacaksa, FK violation onlemek icin **gercek bir stok_id** kullanilmali:
>
> ```sql
> -- Once gercek bir stok ID al
> SELECT id FROM public.stok WHERE kategori = 'Ilac' AND aktif = true LIMIT 1;
> -- Ornek: 'b2c3d4e5-...' gibi text UUID
> ```
>
> Sonra Step 2.9'u su sekilde calistir (placeholder yerine gercek ID):
>
> ```python
> real_stok_id = "b2c3d4e5-f6a7-8901-2345-6789abcdef01"  # SELECT'ten gelen
> test_result = supabase_rpc(
>   function_name="add_treatment_day_with_sessions",
>   params=json.dumps({
>     "p_case_id": "00000000-0000-0000-0000-000000000140",
>     "p_date": "2026-06-15",
>     "p_sessions": [
>       {"planned_time":"08:00:00","stok_id":real_stok_id,"dose":20,"unit":"ml","route":"IM"},
>       {"planned_time":"16:00:00","stok_id":real_stok_id,"dose":5,"unit":"ml","route":"IM"}
>     ]
>   })
> )
> ```
>
> Beklenen: `{"ok": true, "day_id": "...", "seans_sayisi": 2, "admin_ids": [...]}`.

- [ ] **Step 2.11: Test verisini temizle (idempotent kalmak icin)**

```sql
-- Test gununu ve bagli her seyi sil
DELETE FROM public.treatment_days
WHERE treatment_date = '2026-06-15' AND seans_sayisi = 2;
-- CASCADE sayesinde treatment_day_uygulamalar, drug_admins (eger FK var), gorev_log (hayvan_id ile degil day_id ile) silinir
-- Stok hareketi iade edilmez (test verisi, kalabilir VEYA silinebilir)
```

Veya daha guvenli: test vakasi ac, sonra kapat. Detay icin bkz. Faz 6.

- [ ] **Step 2.12: Commit (DDL + RPC — D1 fix, TEK commit)**

```bash
git add supabase/migrations/20260611000001_bug059_treatment_sessions.sql
git commit -m "feat(db): BUG-059 1 yeni tablo + 4 ALTER + 4 yeni RPC + 1 guncelleme

Schema:
- Yeni tablo: treatment_day_uygulamalar (saat+ilac+doz+yol, 1 seans = 1 ilac)
- treatment_days.seans_sayisi (geriye uyumlu, default=1)
- gorev_log.seans_admin_id + hedef_saat (seans bazli gorev)
- drug_administrations.seans_admin_id FK (K5 baglantisi)
- 5 partial index (open/late seanslar icin)

RPC'ler:
- add_treatment_day_with_sessions: yeni gun + N seans + N gorev + stok (atomik)
- seans_tamamla: tek seans done/iptal + zincirleme gun done (race guard)
- recete_guncelle: henuz acilmamis gunleri toplu guncelle (DRY delegasyon)
- close_case_with_remaining: vaka erken kapatma + stok iade
- treatment_day_tamamla: seans_sayisi>1 icin 'tum seanslar done' kontrolu (idempotent)

Spec: docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md
21 review bulgusu giderildi (K1-5, Y1-4, O1-3, K-NEW-1, Y-NEW-1, Y-NEW-2, D1, Y-v3-1, O-v3-1, D-v3-1, D-v3-2, D-v3-3)"
```

---

## Faz 3: Ground Truth Sync (Canonical Referans Guncelleme)

> **Neden:** `supabase/migrations/99999999999999_ground_truth.sql` canonical referanstir. Yeni tablo + RPC'ler buraya da eklenmeli, yoksa sonraki oturumlar Pato 12 (spec yazarken ground truth'tan kopyalama) yapamaz.

- [ ] **Step 3.1: Ground truth dosyasinin son satirini bul**

```bash
wc -l supabase/migrations/99999999999999_ground_truth.sql
tail -5 supabase/migrations/99999999999999_ground_truth.sql
```

- [ ] **Step 3.2: Yeni tablo tanimini ekle (CREATE TABLE blogu)**

> **O4 fix stratejisi:** Ground truth "tek CREATE TABLE" felsefesini korumak icin ALTER degil, **CREATE TABLE tanimina kolon ekle (Secim a)**. Bu, ground truth ile migration dosyasini birebir ayni yapar, drift riski sifir.

`treatment_days` tablosunun CREATE TABLE tanimini bul:

```bash
grep -n "CREATE TABLE.*treatment_days" supabase/migrations/99999999999999_ground_truth.sql
```

`treatment_days` tablosuna `seans_sayisi smallint DEFAULT 1` kolonunu EKLE (ALTER yerine CREATE TABLE icinde). Diger 2 ALTER (gorev_log, drug_administrations) icin ayni pattern.

Sonra `treatment_day_uygulamalar` tablosunun tam CREATE TABLE blogunu `treatment_days` tanimindan HEMEN SONRA ekle.

> **Yazim notu:** Bu ekleme ~60 satir. write aracina direkt VERIRKEN hata riski var, edit + append kullan:
>
> 1. `edit` ile ground truth'a bir sentinel yorum ekle: `-- BUG-059: treatment_day_uygulamalar START`
> 2. `edit` ile sentinel'den sonra tablo tanimini ekle
> 3. `edit` ile kapanis sentinel'i ekle: `-- BUG-059: treatment_day_uygulamalar END`

- [ ] **Step 3.3: Kolon tanimlarini CREATE TABLE icine ekle (3 kolon)**

> **O4 fix:** ALTER YOK, her tablonun CREATE TABLE tanimina ilgili kolon EKLE:
>
> - `treatment_days` -> `seans_sayisi smallint DEFAULT 1`
> - `gorev_log` -> `seans_admin_id uuid REFERENCES treatment_day_uygulamalar(id)`, `hedef_saat time`
> - `drug_administrations` -> `seans_admin_id uuid REFERENCES treatment_day_uygulamalar(id)`

Toplam 4 ek kolon (3 tablo + 1 yeni tablo).

- [ ] **Step 3.4: 4 yeni RPC + 1 guncellemeyi ekle**

Ground truth'ta mevcut RPC'ler sirayla (9a, 9b, 9c, 9d, 9e...). Yeni RPC'leri 9f, 9g, 9h, 9i, 9j olarak ekle:

- 9f: `add_treatment_day_with_sessions` (L300-575 spec'ten)
- 9g: `seans_tamamla` (L585-690)
- 9h: `recete_guncelle` (L695-780)
- 9i: `close_case_with_remaining` (L785-840)
- 9j: `treatment_day_tamamla` (L845-1000) — MEVCUT RPC UZERINE YAZ, DROP + CREATE pattern korunur

> **Yazim notu:** Toplam ~750 satir SQL. write aracina TEK SEFERDE VERME. 5 ayri write cagir, her biri tek RPC'yi ekler.

- [ ] **Step 3.5: Ground truth bilesik kontrol**

```bash
# Canonical referans artik yeni tablo ve RPC'leri icermeli
grep -c "treatment_day_uygulamalar" supabase/migrations/99999999999999_ground_truth.sql
grep -c "add_treatment_day_with_sessions" supabase/migrations/99999999999999_ground_truth.sql
grep -c "seans_tamamla" supabase/migrations/99999999999999_ground_truth.sql
grep -c "recete_guncelle" supabase/migrations/99999999999999_ground_truth.sql
grep -c "close_case_with_remaining" supabase/migrations/99999999999999_ground_truth.sql
```

Beklenen: Her biri >= 1 (tablo + 4 RPC).

- [ ] **Step 3.6: Ground truth idempotent mi?**

```bash
# Eger ground truth'u yanlislikla tekrar calistirsak hata vermemeli
grep -c "CREATE OR REPLACE FUNCTION\|DROP FUNCTION IF EXISTS" supabase/migrations/99999999999999_ground_truth.sql
```

Beklenen: 5+ eslesme (yeni 5 RPC'nin hepsi DROP+CREATE pattern).

- [ ] **Step 3.7: Commit**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "docs(ground-truth): BUG-059 canonical referans guncelleme

- treatment_day_uygulamalar tablosu eklendi
- 3 ALTER kolonu (seans_sayisi, seans_admin_id, hedef_saat) eklendi
- 4 yeni RPC (9f-9i) + 1 guncelleme (9j) eklendi

Pato 12: gelecek oturumlar spec yazarken bu referanstan kopyalayacak.
Migration dosyasi: supabase/migrations/20260611000001_bug059_treatment_sessions.sql"
```

---

## Faz 4: Deploy + Canli Dogrulama

> **Hedef:** Migration canliya gecti, sema + RPC'ler dogrulandi, geriye uyumluluk smoke test gecti.

> **Onemli:** Bu Faz "deploy" degil — `supabase_migrate` zaten Faz 1 ve 2'de canliya gonderdi. Bu Faz SADECE dogrulama + smoke test.

- [ ] **Step 4.0: Son durum kontrol**

```bash
cd /root/egesut-erp1
git log --oneline -5
git status
```

Beklenen: 3 commit (schema, RPC, ground truth), working tree clean.

- [ ] **Step 4.1: Snapshot al (mevcut 4 vaka + aktif tedavi gunleri)**

```sql
-- Mevcut 4 vakanin durumu (geriye uyumluluk referansi)
SELECT c.id, c.animal_id, c.status,
  COUNT(DISTINCT td.id) AS day_count,
  COUNT(DISTINCT da.id) AS drug_admin_count,
  COUNT(DISTINCT g.id) FILTER (WHERE g.gorev_tipi = 'TEDAVI_GUN') AS tedavi_gorev_count
FROM public.cases c
LEFT JOIN public.treatment_days td ON td.case_id = c.id
LEFT JOIN public.drug_administrations da ON da.treatment_day_id = td.id
LEFT JOIN public.gorev_log g ON (g.aciklama::jsonb->>'day_id')::uuid = td.id AND g.gorev_tipi = 'TEDAVI_GUN'
WHERE c.status = 'active'
GROUP BY c.id, c.animal_id, c.status
ORDER BY c.id;
```

Sonuclari not et (Faz 4.9'da karsilastirma icin). Beklenen: 4 vaka, day_count degisken.

- [ ] **Step 4.2: Mevcut 4 vakada seans tablosu bos mu?**

```sql
-- Yeni tablo geriye uyumlu: mevcut 4 vakada HIC seans olmamali
SELECT COUNT(*) AS eski_vakalardaki_seans_sayisi
FROM public.treatment_day_uygulamalar tdu
WHERE tdu.case_id IN (SELECT id FROM public.cases WHERE status = 'active');
```

Beklenen: 0 (eski vakalarda yeni seans tablosu bos, cunku migration geriye uyumlu).

- [ ] **Step 4.3: Mevcut 4 vakayi dashboard'da ac (canli test)**

Arac: Manuel (kullanici) veya `edge_stat` ile ozet kontrol.

Kullaniciya sor: "Mevcut 4 vakayi (140, 5, 7, 9) dashboard'da ac, gorunum bozulmamis mi?"

- [ ] **Step 4.4: Tedavi modalini eski usul ac (tek seans)**

Mevcut bir vakanin tedavi modalini ac, tek seans + 1 saat gir, kaydet.

Beklenen: `add_treatment_day` (eski) cagirilir, `seans_sayisi=1`, yeni seans tablosuna HICBIREY eklenmez. Mevcut UI ayni calisir.

- [ ] **Step 4.5: SQL fonksiyonu dogrula (psql yok, supabase_rpc ile)**

Senaryo A (eski davranis):
```python
result = supabase_rpc(
  function_name="add_treatment_day",
  params='{"p_case_id": "00000000-0000-0000-0000-000000000140", "p_date": "2026-07-01", "p_planned_time": "08:00:00"}'
)
```

Beklenen: `{"ok": true, "day_id": "...", "day_no": ..., "gecmis": false}`.

- [ ] **Step 4.6: Test verisini temizle (Faz 4.5 sonucu)**

```sql
DELETE FROM public.treatment_days WHERE treatment_date = '2026-07-01';
-- CASCADE tedavi_uygulamalar + gorev_log siler (eger FK varsa)
-- Stok hareketi kalir (iyade yok, test verisi)
```

- [ ] **Step 4.7: Senaryo B smoke test (yeni davranis)**

```python
result = supabase_rpc(
  function_name="add_treatment_day_with_sessions",
  params='{"p_case_id": "00000000-0000-0000-0000-000000000005", "p_date": "2026-07-02", "p_sessions": [{"planned_time":"08:00:00","stok_id":"test-stok-1","dose":20,"unit":"ml","route":"IM"},{"planned_time":"16:00:00","stok_id":"test-stok-2","dose":5,"unit":"ml","route":"IM"},{"planned_time":"22:00:00","stok_id":"test-stok-1","dose":20,"unit":"ml","route":"IM"}]}'
)
```

Beklenen: `{"ok": true, "day_id": "...", "seans_sayisi": 3, "admin_ids": [...3 ids]}`.

- [ ] **Step 4.8: Senaryo B veri dogrulamasi (DB'de kontrol)**

```sql
-- treatment_days 1 satir, seans_sayisi=3
-- treatment_day_uygulamalar 3 satir
-- drug_administrations 3 satir (seans_admin_id dolu)
-- gorev_log 4 satir (1 TEDAVI_GUN + 3 TEDAVI_SEANS)
-- stok_hareket 3 satir (seans referansi ile, SADECE test gunu izole)

SELECT
  (SELECT COUNT(*) FROM public.treatment_days WHERE treatment_date='2026-07-02') AS day_count,
  (SELECT COUNT(*) FROM public.treatment_day_uygulamalar tdu
    JOIN public.treatment_days td ON td.id = tdu.treatment_day_id
    WHERE td.treatment_date='2026-07-02') AS seans_count,
  (SELECT COUNT(*) FROM public.drug_administrations da
    JOIN public.treatment_days td ON td.id = da.treatment_day_id
    WHERE td.treatment_date='2026-07-02') AS drug_admin_count,
  (SELECT COUNT(*) FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.treatment_date='2026-07-02') AS gorev_count,
  -- O2 fix: treatment_date filtresi ile izole (LIKE + created_at guvenilmez)
  (SELECT COUNT(*) FROM public.stok_hareket sh
    WHERE sh.created_at::date = '2026-07-02'
      AND sh.iptal = false
      AND sh.notlar LIKE 'drug_admin:%') AS stok_hareket_count;
```

Beklenen: day=1, seans=3, drug_admin=3, gorev=4, stok_hareket=3 (sadece test gunu).

- [ ] **Step 4.9: Snapshot karsilastirma (veri kaybi yok)**

Faz 4.1'deki snapshot ile su anki sayilari karsilastir:

```sql
-- Eski snapshot ile yeni snapshot ayni olmali (sadece test verisi eklendi)
SELECT c.id, c.animal_id,
  COUNT(DISTINCT td.id) AS day_count,
  COUNT(DISTINCT da.id) AS drug_admin_count
FROM public.cases c
LEFT JOIN public.treatment_days td ON td.case_id = c.id
LEFT JOIN public.drug_administrations da ON da.treatment_day_id = td.id
WHERE c.id != '00000000-0000-0000-0000-000000000005'  -- test vakasi haric
  AND c.status = 'active'
GROUP BY c.id, c.animal_id
ORDER BY c.id;
```

Beklenen: 3 vaka (140, 7, 9 — 5 test icin kullanildi), snapshot ile ayni day_count + drug_admin_count.

- [ ] **Step 4.10: Test verisini temizle (Faz 4.7 sonucu)**

```sql
DELETE FROM public.treatment_days WHERE treatment_date IN ('2026-07-01', '2026-07-02');
-- Gorev_log cascade ile silinir
-- Stok hareketini iade etmek icin:
UPDATE public.stok_hareket SET iptal = true
WHERE notlar LIKE 'drug_admin:%' AND created_at > now() - interval '1 hour' AND iptal = false;
```

- [ ] **Step 4.11: Son temiz dogrulama**

```sql
SELECT
  (SELECT COUNT(*) FROM public.treatment_days WHERE treatment_date >= '2026-06-11') AS yeni_gun,
  (SELECT COUNT(*) FROM public.treatment_day_uygulamalar) AS toplam_seans,
  (SELECT COUNT(*) FROM public.gorev_log WHERE gorev_tipi = 'TEDAVI_SEANS') AS seans_gorev;
```

Beklenen: Hepsi 0 (test verisi temizlendi).

- [ ] **Step 4.12: Commit (opsiyonel — sadece test verisi silindiyse)**

Test verisi sadece DB'de, dosya degisikligi yok. Commit YAPMA.

---

## Faz 5: UI Implementasyonu

> **Hedef:** 3 UI degisikligi: (a) Tedavi modal accordion seans listesi, (b) renderTask saat rozeti, (c) Vaka modal plan accordion.

> **Onemli:** Vanilla JS, no bundler, GitHub Pages CDN. Mevcut pattern'i KORU, dokunma.

- [ ] **Step 5.0: Mevcut UI pattern'i anla (degistirmeden once)**

Araclar: `ast_grep_search` + `gitnexus_context`

```bash
ast_grep_search(pattern="renderTask(\$\$\$)", lang="javascript", path="/root/egesut-erp1/js", max_results=3, context_lines=5)
ast_grep_search(pattern="toggleSub(\$\$\$)", lang="javascript", path="/root/egesut-erp1/js", max_results=3, context_lines=3)
gitnexus_context(symbol="renderTask", repo="egesut-erp1")
gitnexus_context(symbol="toggleSub", repo="egesut-erp1")
```

Hedef: Mevcut `renderTask` ve `toggleSub` mantigini anla, GENISLET, dokunma. Yeni dosya YAPMA, mevcut fonksiyonlara paramètre ekle.

- [ ] **Step 5.1: js/api.js'e yeni RPC helper'lari ekle**

`add_treatment_day` satirinin YANINA `add_treatment_day_with_sessions` ekle. Mevcut pattern:

```javascript
add_treatment_day:         ['cases','treatment_days'],
close_case:                ['cases'],
```

Yeni entry'ler:

```javascript
add_treatment_day_with_sessions: ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'gorev_log'],
seans_tamamla:                   ['gorev_log', 'treatment_day_uygulamalar', 'stok_hareket'],
recete_guncelle:                 ['cases', 'treatment_days', 'gorev_log'],
close_case_with_remaining:       ['cases', 'treatment_days', 'gorev_log', 'stok_hareket'],
```

- [ ] **Step 5.2: js/forms.js'e yeni RPC cagrisi wrapper'lari ekle (opsiyonel)**

Mevcut `addTreatmentDay` ve `closeCase` wrapper'lari varsa, `addTreatmentDayWithSessions` ve `seansTamamla` wrapper ekle. Mevcut `addDrugAdministration` benzeri pattern.

> **Kontrol:** Eger mevcut kod `rpc('add_treatment_day', {...})` seklinde dogrudan cagri yapiyorsa, wrapper YAPMA, dogrudan cagri kullan.

- [ ] **Step 5.3: Tedavi modal — A+B Hibrit (Soru 6)**

Hedef dosya: `js/ui.js` — mevcut tedavi modal fonksiyonunu bul (grep: `tedaviModalAc` veya `openTedaviModal`).

```bash
grep -n "tedaviModalAc\|openTedaviModal\|Tedavi Modal" js/ui.js | head -10
```

Mevcut modalda yapilacak degisiklikler:
1. "Planned Time" alanini kaldir (cift kafa karisikligi)
2. "⏰ Seans Listesi" accordion bolumu ekle (baslangicta 1 bos seans)
3. Her seans satiri: saat input + ilac select + doz input + yol select
4. "+ Seans Ekle" butonu (max 10), "🗑️" sil butonu
5. Kaydet: `p_sessions` 1 ise NULL gonder (eski davranis), 2+ ise `[{...}, ...]` gonder

**Yazim notu:** Bu degisiklik ~200 satir JS. write aracina tek seferde VERME, edit + sentinel pattern ile parcali ekle:
- Sentinel 1: `// BUG-059: SEANS ACCORDION START`
- Sentinel 2: `// BUG-059: SEANS ACCORDION END`
- Sentinel 3: `// BUG-059: KAYDET HANDLER START`
- Sentinel 4: `// BUG-059: KAYDET HANDLER END`

- [ ] **Step 5.4: renderTask saat rozeti (Soru 6b)**

Hedef fonksiyon: `renderTask` (js/ui.js:484).

Mevcut `subHtml` (subs render) ve `drugHtml` (drugs render) korunur. Yapilacak:
1. `subs` parametresi artik `gorev_log`'dan TEDAVI_SEANS tipinde cekilecek (mevcut `parent_id` ile ayni pattern)
2. Her sub satirinda saat + ilac adi goster: `🕐 08:00 — PenStrep 20ml IM`
3. Saati gecmis ve done olmamis sub'lar `late` class (mevcut renklendirme)
4. Bugun sub'lari `soon` class, yarin `near` class (mevcut pattern)
5. Toplam rozet: `7/10 tamamlandi` (mevcut `st-prog` korunur)

`gorev_log` aciklama JSON'inda yeni key'ler: `seans_no`, `planned_time`, `admin_id`. Mevcut `label` parse mantigi (`JSON.parse(aciklama).label`) ile uyumlu.

- [ ] **Step 5.5: Vaka modal — Plan Accordion (Soru 7)**

Hedef: Vaka modalina yeni "📅 Tedavi Plani" accordion bolumu ekle.

Mevcut vaka modal fonksiyonunu bul:

```bash
grep -n "openCaseDet\|renderCaseTimeline\|caseDetAc" js/ui.js | head -10
```

Yapilacak:
1. Vaka modalinda yeni accordion: "📅 Tedavi Plani"
2. 5 gunluk plan accordion -> her gun accordion -> her seans listesi
3. Kilitli gunler 🔒 ikonu (gun.done = false VE tamamlanmamis seans varsa)
4. Henuz acilmamis gunler: "Henuz acilmadi (1. gun done olunca acilir)" gri
5. Acilmis ama tamamlanmamis: 🟡 sari, seans tiklaninca `seans_tamamla(admin_id, false, not)`
6. Tamamlanmis: 🟢 yesil, saatler soluk
7. "✏️ Receteyi Duzenle" butonu: yeni modal acar, multi-select gun secimi, recete_guncelle cagirir

- [ ] **Step 5.5a: D3 fix — Vaka kapatma dual dispatch**

> **D3 fix:** `caseKapat()` fonksiyonu seans_sayisi'na gore farkli RPC cagirir:

```javascript
// js/ui.js — caseKapat fonksiyonunu guncelle
async function caseKapat() {
  if (!_curCase) return;
  if (!confirm('Vakayı kapatmak istiyor musunuz?')) return;
  try {
    // D3 fix: seans_sayisi bazli dispatch
    const seansSayisi = await getSeansSayisi(_curCase.id);  // SUM(seans_sayisi) veya MAX
    if (seansSayisi > 1) {
      // Yeni vakalarda: stok iade + uygulanmadi flag
      const not = prompt('Erken kapatma sebebi (opsiyonel):', '');
      await rpc('close_case_with_remaining', {
        p_case_id: _curCase.id,
        p_not: not || null
      });
      toast('✅ Vaka erken kapatildi, kalan seanslar iade edildi');
    } else {
      // Eski vakalarda: orijinal davranis
      await rpc('close_case', { p_case_id: _curCase.id });
      toast('✅ Vaka kapatildi');
    }
    await pullTables(['cases', 'diseases', 'kizginlik_log']);
    await openCaseDet(_curCase.id);
  } catch(e) { toast(e.message, true); }
}

async function getSeansSayisi(caseId) {
  const { data } = await db.from('treatment_days')
    .select('seans_sayisi')
    .eq('case_id', caseId)
    .order('seans_sayisi', { ascending: false })
    .limit(1);
  return data?.[0]?.seans_sayisi || 1;
}
```

**Mantik:**
- `seans_sayisi=1` vakalari -> `close_case` (eski, dokunulmaz, 4 mevcut vaka)
- `seans_sayisi>1` vakalari -> `close_case_with_remaining` (yeni, stok iade + uygulanmadi flag)

- [ ] **Step 5.6: Dashboard rozetleri (Soru 6d)**

Mevcut `renderTask` zaten `late/soon/near` class'lari ile renklendirir. Yapilacak:
1. 🔴 Geciken seans: `planned_time + 3h grace` < now, done degil
2. ⏳ Bugun seansi: planned_date = today
3. 💊 Yarin seansi: planned_date = tomorrow
4. 📅 Acilacak: sadece vaka modalinda, ayri rozet

Mevcut `tbadge` (task badge) hesaplamasi korunur, sadece gec seanslar eklenir.

- [ ] **Step 5.7: Recete degisikligi UI (Soru 6e)**

Yeni modal: "Receteyi Duzenle"
- Multi-select checkbox: gun 2, 3, 4, 5
- Acilmis ve tamamlanmis gunler secilemez (gri, tooltip)
- "Secili gunleri yeniden planla" -> saat + ilac tekrar girilir
- Kaydet: `recete_guncelle(case_id, [{day_no:2, sessions:[...]}, ...])`
- Sonuc: "✅ 4 gun / 12 seans guncellendi, stok ledger'i duzeltildi"

- [ ] **Step 5.8: Frontend smoke test (manuel)**

Kullaniciya sor: "Mevcut 4 vakayi (140, 5, 7, 9) dashboard'da ac, yeni seans accordion'u gorunuyor mu? Tek seansli vakalar eski usul mu calisiyor?"

- [ ] **Step 5.9: GitNexus impact (UI degisikligi sonrasi)**

```python
gitnexus_detect_changes(scope=staged)
```

Beklenen: Sadece `js/ui.js` + `js/api.js` + `js/forms.js` degisti, baska dosya etkilenmedi.

- [ ] **Step 5.10: Commit (UI)**

```bash
git add js/api.js js/forms.js js/ui.js
git commit -m "feat(ui): BUG-059 saat bazli seans UI

- Tedavi modal: A+B hibrit (mevcut modal + accordion seans listesi)
- renderTask: saat + ilac rozetli sub render
- Vaka modal: 'Tedavi Plani' accordion (gun bazli)
- Recete duzenleme modal: multi-select gun + recete_guncelle cagirisi
- Dashboard: late/soon/near rozetler (mevcut pattern korundu)

Spec: docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md
Mevcut 4 vakaya dokunulmadi (geriye uyumlu)"
```

---

## Faz 6: Test Senaryolari (A-J, 10 adim)

> **Hedef:** Spec'teki 10 senaryonun hepsi canli DB'de end-to-end PASS.

> **Onemli:** Her senaryo sonunda TEST VERISI TEMIZLENMELI. Aksi halde 4 mevcut vakaya karisabilir.

- [ ] **Step 6.0: Test vakasi olustur (her senaryo icin izole)**

```sql
-- Her senaryo icin yeni bir test vakasi ac (mevcut vakalara dokunma)
INSERT INTO public.cases (id, animal_id, status, ...)
VALUES ('11111111-1111-1111-1111-000000000001', 'TEST-ANIMAL-1', 'active', ...);
```

Veya daha basit: Mevcut 4 vakadan birini (140) kullan, tedavi gunlerini `treatment_date >= '2026-07-01'` ile izole et.

- [ ] **Step 6.1: Senaryo A — 1 gun × 1 seans (eski davranis)**

Spec L988. RPC: `add_treatment_day(p_case_id, '2026-07-10', '08:00:00')`.

Beklenen:
- `treatment_days` 1 satir, `seans_sayisi=1` (default)
- `treatment_day_uygulamalar` BOS
- `drug_administrations` BOS (eski akis, ayri cagriliyor)
- `gorev_log` 1 satir (TEDAVI_GUN)
- `stok_hareket` BOS (drug_admin yok)

Dogrulama SQL:
```sql
SELECT
  (SELECT seans_sayisi FROM public.treatment_days WHERE treatment_date='2026-07-10' AND case_id='11111111-1111-1111-1111-000000000001') AS seans_sayisi,
  (SELECT COUNT(*) FROM public.treatment_day_uygulamalar tdu JOIN public.treatment_days td ON td.id=tdu.treatment_day_id WHERE td.treatment_date='2026-07-10') AS seans_count;
```

Beklenen: 1, 0.

- [ ] **Step 6.2: Senaryo B — 1 gun × 3 seans + hepsi done**

Spec L989. RPC 1: 3 seans ekle, ardindan 3 kez `seans_tamamla` cagir.

Beklenen:
- 3 `treatment_day_uygulamalar`, hepsi `uygulama_tamamlandi_at` dolu
- 3 `drug_administrations` (seans_admin_id dolu)
- 4 `gorev_log` (1 ana + 3 seans, hepsi done)
- 1 `treatment_days` tamamlandi (zincirleme)
- Stok 3 kez dusmus (1 ilac 2 kez + 1 ilac 1 kez)

- [ ] **Step 6.3: Senaryo C — 5 gun × 3 seans + recete ortasinda degisim**

Spec L990. RPC 1 ile 5 gun × 3 seans ac. 1. gun done. 2. gun henuz acilmamis durumdayken RPC 3 ile 2. gun planini degistir (2 -> 3 seans).

Beklenen:
- Gun 1 etkilenmez
- Gun 2: 2 seans silindi + 3 yeni seans + stok iade (eski 2) + stok dus (yeni 3)
- Gun 3-5 etkilenmez

- [ ] **Step 6.4: Senaryo D — Vaka erken kapatma**

Spec L991. 1 gun × 3 seans, 2 done, 1 acik -> `close_case_with_remaining(case_id, 'tedavi yarida kaldı')`.

Beklenen (D1 fix - Y3 tutarli):
- Kalan 1 seans `uygulanmadi=true` (DONE degil)
- `drug_admins.uygulanmadi=true` (K5 FK uzerinden)
- `stok_hareket.iptal=true` (stok iade)
- Gun done, gorev done, vaka kapali, audit log

- [ ] **Step 6.5: Senaryo E — 1 gun × 3 seans + uygulanmadi**

Spec L992. 1. seans done, 2. seans `seans_tamamla(admin_id, true, 'stok iade')`, 3. seans done.

Beklenen:
- Seans 2: `uygulanmadi=true` + `drug_admin.uygulanmadi=true` + `stok_hareket.iptal=true`
- Seans 1+3: `uygulama_tamamlandi_at` dolu, stok dusmus
- Gun done, audit log

- [ ] **Step 6.6: Senaryo F — Mevcut 4 vakaya dokunulmamasi**

Spec L993. Mevcut 140, 5, 7, 9 vakalari ac, "Tedavi Plani" accordion goruntule.

Beklenen:
- Eski tek-seans davranisi (geriye uyumlu)
- `treatment_day_uygulamalar` bu 4 vaka icin BOS
- Sadece `treatment_days` mevcut
- Mevcut `drug_administrations` (NULL seans_admin_id) etkilenmemis

- [ ] **Step 6.7: Senaryo G — Race condition**

Spec L994. Tab acilir, 2 sekme ayni anda `seans_tamamla(admin_id, false)` cagirir.

Beklenen:
- 1. cagri `ok=true`
- 2. cagri `ok=false, race=true` (SELECT FOR UPDATE guard)
- Sadece 1 satir done
- Stok 1 kez dusulmus (2. cagri noop)

- [ ] **Step 6.8: Senaryo H — Recete degisikligi — kismen acilmis gun**

Spec L995. 5 gun × 3 seans planlanir -> 2. gun ilk seansi done -> `recete_guncelle` ile 2. gun plana yeni seans eklenmeye calisilir.

Beklenen:
- 2. gun `kismen_acik=true` (en az 1 seansi done), ATLANIR
- 1, 3, 4, 5. gun guncellenir (ama 1 done, 3-5 acilmamis — sadece 2 etkilenir)
- 2. gun eski haliyle kalir (3 seans, 1 done, 2 acik)

- [ ] **Step 6.9: Senaryo I — Recete tamamen yeni plana gecis**

Spec L996. 5 gun × 3 seans planlanir -> 1. gun done, 2. gun tamamen acilmis (3 seans acik, 0 done) -> `recete_guncelle` ile 2. gun plana 4 seans eklenir.

Beklenen:
- 2. gun: 3 eski seans silindi (stok iade) + 4 yeni seans + 4 yeni gorev
- Gun 1 etkilenmez
- Gun 3-5 degismez

- [ ] **Step 6.10: Senaryo J — Vaka erken kapatma + 1 seans acik**

Spec L997. 5 gun × 3 seans, gun 1-2 done, gun 3 ilk seans done + 2 acik, gun 4-5 tamamen acik -> `close_case_with_remaining(case_id, 'iptal')`.

Beklenen:
- Gun 3-5 kalan 5 acik seans `uygulanmadi=true`
- `drug_admins.uygulanmadi=true` (O2 fix)
- `stok_hareket.iptal=true` (stok iade, drug_admins INSERT aninda dusmustu)
- Gun 3-5 done, vaka kapali, audit log "5 seans erken kapatildi, stok iade edildi"

- [ ] **Step 6.11: Tum senaryolar PASS mi?**

| Senaryo | Sonuc |
|---|---|
| A: 1×1 eski | ☐ |
| B: 1×3 done | ☐ |
| C: 5×3 recete ortasinda | ☐ |
| D: vaka erken kapatma | ☐ |
| E: 1×3 uygulanmadi | ☐ |
| F: 4 mevcut vaka | ☐ |
| G: race condition | ☐ |
| H: kismen acilmis | ☐ |
| I: yeni plana gecis | ☐ |
| J: vaka kapatma + acik seans | ☐ |

Hepsi ☐ ise Faz 7'ye gec. Biri FAIL ise hata analizi yap, spec/RPC'de fix, senaryoyu tekrar calistir.

- [ ] **Step 6.12: Test verilerini temizle (her senaryo sonrasi)**

```sql
-- O1 fix: uuid tipinde LIKE calismaz, = 'uuid'::uuid veya IN kullan
-- Tum test senaryolari 2026-07-01 - 2026-07-15 araliginda calistirilir
-- O2 fix: tarih filtresi ile izole (LIKE + created_at guvenilmez)

-- Test vakalarini kapat (tarih araligindaki vakalar)
UPDATE public.cases SET status = 'closed', closed_at = now()
WHERE id IN (
  SELECT DISTINCT case_id FROM public.treatment_days
  WHERE treatment_date BETWEEN '2026-07-01' AND '2026-07-15'
);

-- Test gunlerini sil (CASCADE seanslari + drug_admins + gorev_log siler)
DELETE FROM public.treatment_days
WHERE treatment_date BETWEEN '2026-07-01' AND '2026-07-15';

-- Stok hareketini iade et (O2 fix: tarih filtresi)
UPDATE public.stok_hareket SET iptal = true
WHERE created_at::date BETWEEN '2026-07-01' AND '2026-07-15'
  AND notlar LIKE 'drug_admin:%' AND iptal = false;

-- islem_log temizligi (opsiyonel, audit trail kalabilir)
```

- [ ] **Step 6.13: Commit (test sonuclari)**

Test verisi SQL degisikligi yok, commit YAPMA. Ancak test sonuclarini docs'a ekle:

```bash
# docs/superpowers/plans/2026-06-11-test-sonuclari.md
# Senaryo A-J tablosu, hepsi PASS
git add docs/superpowers/plans/2026-06-11-test-sonuclari.md
git commit -m "test: BUG-059 10 senaryo PASS (A-J)"
```

---

## Faz 7: Session Update + Handoff

> **Hedef:** Tum is kanitlari kaydedildi, sonraki oturum icin handoff hazir.

- [ ] **Step 7.1: tools-bank memory'ye kritik kararlar ekle**

```python
memory_add(
  content="BUG-059 saat bazli seans IMPLEMENT EDILDI (2026-06-11): 1 yeni tablo treatment_day_uygulamalar + 4 ALTER kolon + 4 yeni RPC + 1 guncelleme. K1 fix: stok_hareket.id text FK. K2/K3 fix: stok INSERT atomik drug_admins ile. K5 FK: drug_admins.seans_admin_id. K-NEW-1 C cozumu: recete_guncelle -> add_treatment_day_with_sessions (p_existing_day_id ile delegasyon, DRY). Idempotent: treatment_day_tamamla zaten-tamamlanmış noop. 4 vakaya dokunulmadi (geriye uyumlu). Spec: docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md. Plan: docs/superpowers/plans/2026-06-11-bug-059-saat-bazli-seans.md.",
  category="code_change",
  priority="high",
  tags="BUG-059,seans,tedavi,RPC,ground-truth"
)
```

- [ ] **Step 7.2: Mevcut TODO listesini kapat**

Mevcut TODO listenin tamamini `[x]` isaretle (veya temizle + yeni "kapanis" checklist'i olustur).

- [ ] **Step 7.3: Handoff dosyasi guncelle (varsa)**

```bash
# Eger /root/tools-bank/handoff/ veya benzeri dosya varsa
# "Son tamamlanan: BUG-059" notu ekle
```

- [ ] **Step 7.4: Son commit (session kapatma)**

```bash
cd /root/egesut-erp1
git log --oneline -10
git status
```

Calisma tree temiz olmali (son test verisi silindi).

- [ ] **Step 7.5: Kullaniciya ozet**

Kullaniciya sonucu raporla:
- Kac commit atildi
- Hangi dosyalar degisti
- Tum senaryolar PASS mi
- Bilinen sinirlamalar / TODO (varsa)

---
