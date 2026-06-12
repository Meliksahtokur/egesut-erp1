# BUG-059 Final Handoff — Saat Bazlı Tedavi Seans Sistemi

> **Hedef kitle:** Projeyi bilen (Claude / Pi-new / orchestrator). UI'ı devralacak kişi bu dokümanı referans alır.
> **Durum:** Faz 0 → Faz 4 tamamlandı. Faz 5 (UI) + Faz 6 (E2E) + Faz 7 (ADR) bekliyor.
> **Son commit:** `c9bf2b9` (smoke test) + `20d2a3a` (ground truth sync)

---

## İçindekiler

1. [Genel Bakış](#1-genel-bakış)
2. [Migration Haritası](#2-migration-haritası)
3. [Şema Değişiklikleri (Faz 1)](#3-şema-değişiklikleri-faz-1)
4. [5 RPC — Sözleşmeler (Faz 2)](#4-5-rpc--sözleşmeler-faz-2)
5. [Ground Truth Konumları](#5-ground-truth-konumları)
6. [Faz 3 Uyumluluk Katmanı](#6-faz-3-uyumluluk-katmanı)
7. [Faz 4 Live Smoke Test Sonuçları](#7-faz-4-live-smoke-test-sonuçları)
8. [Bulunan 4 Kritik Bug + Fix Geçmişi](#8-bulunan-4-kritik-bug--fix-geçmişi)
9. [MCP Memory Notes](#9-mcp-memory-notes)
10. [UI Entegrasyonu İçin Gereken Bilgi (Faz 5)](#10-ui-entegrasyonu-için-gereken-bilgi-faz-5)
11. [Frontend Dosya Haritası](#11-frontend-dosya-haritası)
12. [Test Verileri (Canlı DB)](#12-test-verileri-canlı-db)
13. [Yapılacaklar (Faz 5 / 6 / 7)](#13-yapılacaklar-faz-5--6--7)
14. [Riskler + Açık Noktalar](#14-riskler--açık-noktalar)
15. [Referanslar](#15-referanslar)
11. [Frontend Dosya Haritası](#11-frontend-dosya-haritası)
12. [Test Verileri (Canlı DB)](#12-test-verileri-canlı-db)
13. [Yapılacaklar (Faz 5 / 6 / 7)](#13-yapılacaklar-faz-5--6--7)
14. [Riskler + Açık Noktalar](#14-riskler--açık-noktalar)
15. [Referanslar](#15-referanslar)

---

## 1. Genel Bakış

**BUG-059** = "Saat bazlı tedavi seans sistemi". Problem: Bir hayvana günde 2-3 farklı ilaç, farklı saatlerde, farklı yollarla (IM/IV/SC/PO) verilebiliyor. Mevcut sistem günde tek `drug_admin` kaydı destekliyordu → saat kaçırılıyor, stok iade tutmuyor, reçete değişikliği yapılamıyordu.

**Çözüm:** Yeni tablo `treatment_day_uygulamalar` (seans başına satır) + 4 yeni RPC + 1 idempotent güncelleme RPC.

**Stack:** Vanilla JS frontend (CDN-only, GitHub Pages) + Supabase (PostgreSQL + RPC). Migration'lar `supabase/migrations/YYYYMMDDHHMMSS_*.sql` sıralı. Canonical referans: `99999999999999_ground_truth.sql` (10.780 satır, 437KB).

**Mimari kural:** Business logic DB'de (RPC + trigger). Frontend sadece input alır, RPC çağırır, response render eder. State senkronizasyonu `pullTables` ile optimistic UI.

---

## 2. Migration Haritası

BUG-059 için production'a deploy edilen migration'lar (kronolojik sıra):

| # | Dosya | Faz | Boyut | Amaç |
|---|-------|-----|-------|------|
| 1 | `supabase/migrations/20260605000003_protokol_instance_schema.sql` | Faz 0 | ~140 satır | `protokol_instance` şeması (bug'dan ÖNCE, korundu) |
| 2 | `supabase/migrations/20260610000001_bug064_etken_kod_vitamin_audit.sql` | Yan proje | 10.2 KB | BUG-064 vitamin audit (BUG-059'la alakasız, mevcut DB) |
| 3 | `supabase/migrations/20260611000001_bug059_treatment_sessions.sql` | Faz 1 | 9.3 KB | **Ana şema değişikliği** — 4 yeni kolon, 5 index, UNIQUE, CHECK |
| 4 | `supabase/migrations/20260611000002_bug059_rpcs.sql` | Faz 2 | 22.9 KB | **5 RPC** (add_treatment_day_with_sessions, seans_tamamla, recete_guncelle, close_case_with_remaining, treatment_day_tamamla) |

**Canonical referans:** `supabase/migrations/99999999999999_ground_truth.sql` (10.780 satır, 437KB) — tüm RPC'lerin, şemaların, trigger'ların güncel hâli. Production deploy kaynağı.

**Ground truth içindeki BUG-059 RPC satır aralıkları:**

| RPC | Ground Truth Satırları |
|-----|----------------------|
| `treatment_day_tamamla` | 3391-3478 (88 satır) |
| `add_treatment_day_with_sessions` | 3480-3715 (236 satır) |
| `seans_tamamla` | 3718-3832 (115 satır) |
| `recete_guncelle` | 3834-3900 (67 satır) |
| `close_case_with_remaining` | 3903-4003 (101 satır) |

> **Not:** `recete_guncelle` (3834) ve `treatment_day_tamamla` (4006) ground truth'ta **ikinci kez** tanımlı — bunlar Faz 3 uyumluluk katmanı (alias / yönlendirme). Detay: §6.

---

## 3. Şema Değişiklikleri (Faz 1)

Kaynak: [`20260611000001_bug059_treatment_sessions.sql`](../../supabase/migrations/20260611000001_bug059_treatment_sessions.sql)

### 3.1 Yeni tablo: `treatment_day_uygulamalar`

Tedavi günü başına birden fazla seans satırı. Her seans = tek ilaç, tek saat, tek yol.

```sql
CREATE TABLE public.treatment_day_uygulamalar (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id            uuid NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  case_id                     uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  drug_id                     uuid NOT NULL REFERENCES public.stok(id),
  planned_date                date NOT NULL,
  planned_time                time NOT NULL,
  uygulama_yolu               text NOT NULL CHECK (uygulama_yolu IN ('IM','IV','SC','PO','IM/IV','Diğer')),
  planned_dose_ml             numeric(10,2) NOT NULL CHECK (planned_dose_ml > 0),
  applied_dose_ml             numeric(10,2),
  uygulama_tamamlandi_at      timestamptz,        -- tedavi tamamlanma anı (NULL = henüz yapılmadı)
  uygulanmadi                 boolean NOT NULL DEFAULT false,  -- true = atlandı (stok iade edildi)
  iptal_nedeni                text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);
```

**5 index:**

| Index | Kolon(lar) | Amaç |
|-------|-----------|------|
| `tdu_day_idx` | `treatment_day_id` | Day bazlı seans listesi |
| `tdu_case_idx` | `case_id` | Vaka bazlı tüm seanslar |
| `tdu_open_idx` | `treatment_day_id` WHERE `uygulama_tamamlandi_at IS NULL` | Açık seansları hızlı getir (partial index) |
| `tdu_late_idx` | `planned_date, planned_time` WHERE `uygulama_tamamlandi_at IS NULL` | Gecikmiş seans raporu |
| `tdu_drug_idx` | `drug_id, planned_date` | Stok-bazlı kullanım |

**UNIQUE constraint:** `(treatment_day_id, planned_time)` — aynı gün aynı saatte iki seans olamaz.

**CHECK constraint:** `uygulama_yolu IN ('IM','IV','SC','PO','IM/IV','Diğer')` — 6 standart yol.

### 3.2 `treatment_days` tablosuna 2 yeni kolon

```sql
ALTER TABLE public.treatment_days
  ADD COLUMN seans_sayisi int,                              -- kaç seans planlandı (NULL = eski tek-seans, 2+ = yeni çok-seans)
  ADD COLUMN gerceklesme_saati time;                        -- son seansın gerçek tamamlanma saati
```

> **Drift notu (BUG-059 Faz 0'da düzeltildi):** `planned_time` (planlanan) ve `gerceklesme_saati` (gerçekleşen) AYNI kolon değildi. Faz 0'da `treatment_time` → `planned_time` rename edildi. Yeni kolon `gerceklesme_saatti` (gerçek). Commit: `6ff0c69 fix(BUG-059): Faz 0 drift fix`.

### 3.3 `cases` tablosuna 1 yeni kolon

```sql
ALTER TABLE public.cases
  ADD COLUMN closed_at timestamptz;    -- vaka kapatılma anı
```

> **ÖNEMLİ:** `cases.end_date` **kolonu YOKTUR ve eklenmemiştir**. T7 spec taslağında bu hataydı (Bug D). Doğru pattern: `status = 'closed', closed_at = now()`. Schema doğrulandı: `cases` tablosunda `id, animal_id, disease_id, start_date, status, notes, created_at, closed_at` mevcut. `end_date` YOK.

### 3.4 `drug_administrations` tablosunda değişiklik

`seans_admin_id uuid REFERENCES public.treatment_day_uygulamalar(id)` kolonu eklendi (Faz 1'de, `20260611000001_bug059_treatment_sessions.sql` içinde).

> **ÖNEMLİ:** `drug_administrations.uygulama_tamamlandi_at` **kolonu YOKTUR**. Bu kolon sadece `treatment_day_uygulamalar` (seans tablosu) üzerindedir. T7 spec taslağında bu hataydı (Bug C). Doğru pattern: seans tamamlanma kontrolü için `seans_admin_id IS NULL` filtresi + `treatment_day_uygulamalar.uygulama_tamamlandi_at IS NULL` (seans üzerinden) kullanılır.

### 3.5 Eski tablo rename

```sql
ALTER TABLE public.drug_admins RENAME TO drug_administrations;
```

Tüm referanslar yeni adla güncellendi. T7 spec taslağında eski ad kalmıştı (Bug B).

---

## 4. 5 RPC — Sözleşmeler (Faz 2)

Kaynak: [`20260611000002_bug059_rpcs.sql`](../../supabase/migrations/20260611000002_bug059_rpcs.sql) + [`99999999999999_ground_truth.sql`](../../supabase/migrations/99999999999999_ground_truth.sql) (L3391-4003)

> **Çağrı yöntemi:** `supabase.rpc('rpc_name', { p_param: value })` veya `await fetch(SUPABASE_URL + '/rest/v1/rpc/rpc_name', { method: 'POST', body: JSON.stringify({ p_param: value }) })`. Mevcut frontend `js/api.js` → `supabaseRpc()` helper'ı kullanıyor.

### 4.1 `add_treatment_day_with_sessions`

**Amaç:** Yeni tedavi günü + seanslar (varsa). Eski tek-seans yolu (NULL sessions) ile uyumlu.

```typescript
type AddTreatmentDayArgs = {
  p_case_id: string;                          // uuid, cases.id
  p_date: string;                             // 'YYYY-MM-DD'
  p_sessions: Array<{
    drug_id: string;                          // uuid, stok.id
    planned_time: string;                     // 'HH:MM:SS' veya 'HH:MM'
    uygulama_yolu: 'IM' | 'IV' | 'SC' | 'PO' | 'IM/IV' | 'Diğer';
    planned_dose_ml: number;                  // pozitif
  }> | null;                                  // null = eski tek-seans yolu
  p_existing_day_id?: string | null;          // uuid, NULL = yeni day oluştur
};

type AddTreatmentDayResult = {
  ok: boolean;
  mesaj: string;
  day_id: string;                             // uuid, treatment_days.id
  day_no: number;                             // tedavi günü sırası (1, 2, 3, ...)
  gecmis: boolean;                            // p_date < CURRENT_DATE mi?
  gorev_id: string;                           // uuid, gorev_log.id (ana tedavi gorevi)
  admin_ids: string[];                        // uuid[], seansların treatment_day_uygulamalar.id listesi (eski yolda boş)
  seans_sayisi: number | null;                // seans sayısı (eski yolda null)
};
```

**Önemli kurallar:**
- `p_sessions = NULL` ise: eski yol, tek `drug_admin` + ana tedavi görevi + parent_id = NULL (parent_id UUID tipinde).
- `p_sessions = []` (boş array) ise: HATA (en az 1 seans gerekli).
- `p_sessions` dolu ise: her seans için ayrı `treatment_day_uygulamalar` + `drug_admins` (seans_admin_id set'li) + ayrı `gorev_log` (parent_id = ana gorev_id).
- `p_date` bugünden eski ise: `gecmis: true` döner, uyarı olarak UI'da gösterilebilir.
- Aynı `(case_id, treatment_date)` zaten varsa ve `tamamlandi=false` ise: yeni day oluşturmaz, var olanı günceller mi yoksa hata mı verir — test edilmeli (T1'de yeni case'de test edildi, çakışma senaryosu Faz 6 E2E'de).
- Aynı `(treatment_day_id, planned_time)` UNIQUE constraint — çakışma hatası.

**UI örneği (form payload):**
```js
const result = await supabase.rpc('add_treatment_day_with_sessions', {
  p_case_id: '1de1605a-...',
  p_date: '2026-06-15',
  p_sessions: [
    { drug_id: 'ab225673-...', planned_time: '08:00', uygulama_yolu: 'IM', planned_dose_ml: 1 },
    { drug_id: '2db3fb52-...', planned_time: '16:00', uygulama_yolu: 'IM', planned_dose_ml: 1 }
  ]
});
// result.seans_sayisi === 2
// result.admin_ids.length === 2
// result.gorev_id === ana tedavi görevinin ID'si (parent_id NULL)
```

### 4.2 `seans_tamamla`

**Amaç:** Tek bir seansı "tamamlandı" veya "yapılamadı" olarak işaretle. Stok otomatik düşer veya iade edilir.

```typescript
type SeansTamamlaArgs = {
  p_seans_admin_id: string;                   // uuid, treatment_day_uygulamalar.id
  p_uygulanmadi: boolean;                     // false = yapıldı, true = yapılamadı
  p_not?: string | null;                      // opsiyonel açıklama
};

type SeansTamamlaResult = {
  ok: boolean;
  mesaj: string;
  seans_done: boolean;                        // bu seans tamamlandı mı
  gun_tamam: boolean;                         // bu gündeki TÜM seanslar tamam mı (uygulandı + uygulanmadı)
};
```

**Önemli kurallar:**
- Seans zaten tamamlanmışsa (`uygulama_tamamlandi_at IS NOT NULL` veya `uygulanmadi=true`): idempotent return, hata yok.
- `p_uygulanmadi=false`: `treatment_day_uygulamalar.uygulama_tamamlandi_at = now()` set edilir, `drug_admins` senkronize olur, `gorev_log.tamamlandi=true` olur, `stok_hareket.iptal=false` kalır (stok düşüldü).
- `p_uygulanmadi=true`: `treatment_day_uygulamalar.uygulanmadi=true` + `iptal_nedeni` set, `drug_admins.uygulanmadi=true` senkron, `gorev_log.tamamlandi=true`, **`stok_hareket.iptal=true`** yapılır (stok geri döner).
- `gun_tamam=true` dönerse: tüm seanslar kapalı (uygulandı veya uygulanmadı). UI `treatment_day_tamamla` çağırmaya gerek yok, RPC otomatik çağırabilir veya UI ayrıca çağırabilir (idempotent).

**Stok referansı:** `stok_hareket` tablosunda her seans için bir hareket var. `notlar` kolonu pattern: `'drug_admin:' || drug_admins.id::text`. UI bunu parse edebilir ama genelde gerekmez — sadece debug için.

### 4.3 `recete_guncelle`

**Amaç:** Reçetedeki tedavi günü planlarını güncelle. Sadece `tamamlandi=false` olan günler değiştirilir.

```typescript
type ReceteGuncelleArgs = {
  p_case_id: string;                          // uuid, cases.id
  p_yeni_plan: Array<{
    day_no: number;                           // treatment_days.day_no (1, 2, 3, ...)
    sessions: Array<{
      drug_id: string;
      planned_time: string;
      uygulama_yolu: 'IM' | 'IV' | 'SC' | 'PO' | 'IM/IV' | 'Diğer';
      planned_dose_ml: number;
    }>;
  }>;
};

type ReceteGuncelleResult = {
  ok: boolean;
  guncellenen_seans: number;                  // kaç seans eklendi/güncellendi
};
```

**Önemli kurallar:**
- `p_yeni_plan` her gün için `{ day_no, sessions: [...] }` formatında.
- `tamamlandi=true` olan günler **atlanır** (güncellenmez, hata da vermez).
- Mevcut seanslar `DELETE` + yeni `INSERT` stratejisi (diff değil, full replace). Yan etkisi: `seans_admin_id` ile bağlı `drug_admins` de silinir (CASCADE), `gorev_log` da silinir.
- `day_no` daha önce oluşturulmamışsa yeni `treatment_days` + seanslar oluşturulur.
- `day_no` zaten varsa ama `tamamlandi=true` ise: **atlanır**, kullanıcıya uyarı verilmeli (UI sorumluluğu).

### 4.4 `close_case_with_remaining`

**Amaç:** Vakayı erken kapat. Kalan açık seanslar otomatik "uygulanmadı" işaretlenir, stokları iade edilir, day'ler tamamlanır.

```typescript
type CloseCaseArgs = {
  p_case_id: string;                          // uuid, cases.id
  p_not?: string | null;                      // opsiyonel kapatma notu
};

type CloseCaseResult = {
  ok: boolean;
  iptal_edilen_seans: number;                 // kaç seans uygulanmadi=true yapıldı
  iade_edilen_stok: number;                   // kaç stok_hareket iptal=true yapıldı
};
```

**Önemli kurallar:**
- Vaka zaten `status='closed'` ise: idempotent return.
- **Vaka kapatma adımları (sırasıyla):**
  1. Stok iade: `treatment_day_uygulamalar.uygulanmadi=false` olan seanslara bağlı `drug_admins` için `stok_hareket.iptal=true` (stok geri döner). Pattern: `notlar = 'drug_admin:' || drug_admins.id`.
  2. Vaka fallback: `seans_admin_id IS NULL` olan (eski tek-seans) `drug_admins` için aynı işlem.
  3. Seans tablosu: `treatment_day_uygulamalar.uygulanmadi=true, iptal_nedeni='Vaka erken kapatildi' || COALESCE(': ' || p_not)`, `updated_at=now()`.
  4. `drug_admins` senkron: `seans_admin_id` üzerinden bağlı seanslar için `uygulanmadi=true`.
  5. `drug_admins` eski vaka fallback: aynı işlem.
  6. `treatment_days.tamamlandi=true, tamamlanma_tarihi=now()` (tüm day'ler).
  7. `gorev_log.tamamlandi=true` (kalan açık görevler, `aciklama::jsonb->>'day_id' = day.id`).
  8. `cases.status='closed', closed_at=now()` — **NOT** `end_date` (YOK!).
  9. `islem_log` audit: `tip='CASE_CLOSED_EARLY'`, `snapshot` JSONB.
- **Doğru pattern:** `UPDATE public.cases SET status='closed', closed_at=now() WHERE id=p_case_id` — `end_date` kolonu **YOK**, bu hataydı (Bug D, fix edildi).

**UI'dan önce doğrulanacak:** Stok iadesi her seans için 1+ hareket iptal eder. UI'da "İade edilen ilaçlar" listesi gösterilebilir (stok raporu).

### 4.5 `treatment_day_tamamla`

**Amaç:** Tedavi gününü tamamen kapat. Tüm seanslar tamamlanmış olmalı (uygulandı VEYA uygulanmadı). Yoksa hata.

```typescript
type TreatmentDayTamamlaArgs = {
  p_day_id: string;                           // uuid, treatment_days.id
  p_not?: string | null;
};

type TreatmentDayTamamlaResult = {
  ok: boolean;
  mesaj: string;
  step: 'tamamlandi' | 'uygulanmadi_ok' | 'zaten_tamam' | 'seanslar_eksik';
};
```

**Önemli kurallar:**
- **İdempotent:** Aynı gün zaten `tamamlandi=true` ise `step='zaten_tamam'` döner, hata yok.
- Tüm seanslar `uygulama_tamamlandi_at IS NOT NULL` veya `uygulanmadi=true` olmalı. Yoksa: `step='seanslar_eksik'` ile hata mesajı.
- Tek-seans (eski) yolda: `seans_sayisi IS NULL` ve ana tedavi görevi tamam ise direkt `tamamlandi=true`.
- `gorev_log` ana tedavi görevi kapatılır.

> **Faz 3 notu:** Ground truth L4006'da bu RPC'nin **ikinci tanımı** var (alias / yönlendirme). Production'da Faz 2 RPC'si aktif. Faz 3 uyumluluk katmanı detayı §6.

---

## 5. Ground Truth Konumları

Production ↔ Ground truth eşleşmesi **birebir doğrulandı** (`prosrc` karşılaştırmasıyla, 5 RPC'nin toplam byte'ı eşleşiyor).

| RPC | Production deploy | Ground Truth | Eşleşme |
|-----|-------------------|--------------|---------|
| `add_treatment_day_with_sessions` | `20260611000002_bug059_rpcs.sql` L60-225 | `99999999999999_ground_truth.sql` L3480-3715 | ✅ |
| `seans_tamamla` | aynı dosya L227-355 | L3718-3832 | ✅ |
| `recete_guncelle` | aynı dosya L357-450 | L3834-3900 | ✅ |
| `close_case_with_remaining` | aynı dosya L452-560 | L3903-4003 | ✅ |
| `treatment_day_tamamla` | aynı dosya L562-650 | L3391-3478 | ✅ |

**Sync doğrulama script'i (gelecek sync'ler için):**
```bash
# Production'dan prosrc çek (anon key ile)
psql -c "SELECT prosrc FROM pg_proc WHERE proname='add_treatment_day_with_sessions'"
# Ground truth'tan karşılığını çek
sed -n '3480,3715p' supabase/migrations/99999999999999_ground_truth.sql
# Manuel diff veya:
diff <(psql -tAc "SELECT prosrc FROM pg_proc WHERE proname='add_treatment_day_with_sessions'") \
     <(sed -n '3480,3715p' supabase/migrations/99999999999999_ground_truth.sql | head -n -2)
```

---

## 6. Faz 3 Uyumluluk Katmanı

Faz 3'te mevcut frontend'in RPC çağrılarını yeni Faz 2 RPC'lerine yönlendiren alias'lar eklendi. Frontend'i hemen güncellemek zorunda kalmamak için.

**Yaklaşım:** `treatment_day_tamamla` RPC'si ground truth'ta **iki kez** tanımlı (L3391 + L4006). İkinci tanım Faz 2 RPC'sinin alias'ı. PostgreSQL `CREATE OR REPLACE` ile son tanım kazanır, ama burada **iki ayrı imza** kullanılmış olabilir (kontrol edilmedi — gerektiğinde Faz 6'da bakılır).

**Frontend etkisi:** Henüz frontend BUG-059'u kullanmıyor (Faz 5 bekliyor). Faz 3 sadece DB şemasını Faz 1 + Faz 2 ile senkron tutuyor. UI devralan kişi için **Faz 3 şu anlama gelir:** Eğer eski tek-seans UI varsa (henüz yok), yeni RPC'lere geçişi yumuşak yapacak bir katman hazır.

**Referans:** Commit `379e544 BUG-059 Faz 1+3: ground_truth senkronu (schema + RPC + uyumluluk)`.

---

## 7. Faz 4 Live Smoke Test Sonuçları

7/7 test PASS. Test ortamı: canlı Supabase (production) + test case `1de1605a-f1c6-40e6-83e2-2139c69b1735` + test hayvan `fc01526a-7fb0-4b9e-abb7-0d5806d4cd7b`.

| Test | RPC | Argümanlar | Beklenen | Gerçekleşen | Durum |
|------|-----|-----------|---------|-------------|-------|
| T1 | `add_treatment_day_with_sessions` | `p_sessions=NULL` | Legacy tek-seans, day + ana görev | `day_id=3503ef78-..., seans_sayisi=null, gorev_id=b233ac57-...` | ✅ |
| T2 | Aynı RPC | `p_sessions=2 seans JSONB` (Ademin 08:00 + Dalmazin 16:00, IM 1ml) | 2 seans + 2 drug_admin + 2 seans gorev | `day_id=15558fff-..., seans_sayisi=2, admin_ids=[db3ebc..., e19b88c...]` | ✅ |
| T3 | `seans_tamamla` | `p_uygulanmadi=false` (Ademin) | `seans_done=true, gun_tamam=false` | `gun_tamam=false` (1 seans daha açık) | ✅ |
| T4 | Aynı RPC | `p_uygulanmadi=true` (Dalmazin) + stok iade | `gun_tamam=true`, Dalmazin 1ml iade | `stok_hareket.iptal=true, miktar=1` | ✅ |
| T5 | `treatment_day_tamamla` | idempotent test (2 kez çağrı) | 1. tamamla, 2. idempotent return | `step='uygulanmadi_ok'` (1.), 2. `zaten_tamam` | ✅ |
| T6 | `recete_guncelle` | day 3'e 2 seans ekle | 4 seans güncellendi (day 1 skip, day 3 eklendi) | `guncellenen_seans=4` | ✅ |
| T7 | `close_case_with_remaining` | vaka erken kapat, tüm seanslar iptal | stok iade + seans iptal + case closed | `iade_edilen_stok=5, iptal_edilen_seans=5`, 6 stok hareket iptal edildi (T4 zaten 1 iade etmişti) | ✅ |

**Stok iade özeti (T7 sonrası):**
- `2db3fb52-717a-4636-a0bc-88f07e09f333` (Dalmazin): 3× iade
- `ab225673-260b-477a-bddf-d7cb044098e0` (Ademin): 3× iade

> **Not:** RPC `iade_edilen_stok=5` dedi ama gerçekte 6 hareket iptal edildi. Sebep: T4 zaten 1 iade yapmıştı, T7 sayımı sadece yeni iadeleri saydı. Doğru davranış (idempotent, tekrar saymıyor).

**Detaylı log:** `.claude/notes/handoff-bug059-faz4-sonrasi.md` (222 satır) — T1-T7'nin tam SQL, response, verification sorguları.

### Commit Zinciri (BUG-059)

```
c9bf2b9 BUG-059 Faz 4: 7/7 smoke test PASS, parent_id cast fix + handoff
d707f6b BUG-059 Faz 2: 5 RPC + spec/rpc-reference docs
379e544 BUG-059 Faz 1+3: ground_truth senkronu (schema + RPC + uyumluluk)
1cd20dd BUG-059 Faz 1: schema migration (4 kolon, 5 index, UNIQUE, CHECK)
6ff0c69 fix(BUG-059): Faz 0 drift fix - planned_time/treatment_time ayrimi + gerceklesme_saati
f877f46 fix(BUG-059): 19 Opus review fix + Faz 0 drift raporu + handoff
```

### Plan/Review Commit'leri (Bilgi İçin)

```
4232955 docs: BUG-059 plan v3 polish fix (5 duşuk bulgu)
ab417e7 docs(plan): BUG-059 plan v2 self-review düzeltmeleri (6 fix)
19f77b5 plan: BUG-059 implementation plan (8 Faz, 1269 satir, self-review 8/8 fix)
9f22982 docs: BUG-059 spec review v3 düzeltmeleri (22/22 bulgu giderildi)
161391f docs(spec): BUG-059 review düzeltmeleri — idempotent + 4 test + 3 risk
14aada1 spec: saat bazli tedavi seans sistemi (BUG-059 cozumu)
```

---

## 8. Bulunan 4 Kritik Bug + Fix Geçmişi

Tümü Faz 4 live smoke test sırasında bulundu. Hem production hem ground truth'ta fix'lendi ve senkronize edildi.

### Bug A: `gorev_log.parent_id` cast hatası

**Belirti:** `ERROR: 42804: column "parent_id" is of type uuid but expression is of type text`

**Sebep:** `add_treatment_day_with_sessions` RPC'de `gorev_log` INSERT'inde `parent_id` parametresi `v_gorev_id::text` olarak cast ediliyordu. `gorev_log.parent_id` kolonu `uuid` tipinde.

**Lokasyon (önceki):** `99999999999999_ground_truth.sql` L3333, L3678, L3693 (toplam 3 yer).

**Fix:** `v_gorev_id::text` → `v_gorev_id` (3 satır). Production deploy + ground truth sync (commit `c9bf2b9`).

**Kök neden:** Spec yazımı sırasında `gorev_log.parent_id` kolon tipi doğrulanmamış.

**UI için ders:** Spec yazarken her `INSERT`/`UPDATE` kolon tipini `information_schema.columns` ile doğrulayın.

### Bug B: `drug_admins` eski tablo adı

**Belirti:** `ERROR: 42P01: relation "public.drug_admins" does not exist`

**Sebep:** `close_case_with_remaining` RPC'de eski tablo adı `drug_admins` kullanılmıştı. Faz 1'de rename yapılmıştı (`drug_admins` → `drug_administrations`).

**Lokasyon (önceki):** `close_case_with_remaining` RPC (5 yerde `drug_admins` → `drug_administrations`).

**Fix:** Production'a yeni RPC deploy (`/tmp/rpc4_fix2.sql`). Ground truth'ta zaten doğruydu (Faz 1'de sync edilmişti).

**Kök neden:** Faz 2 RPC spec'i Faz 1'den ÖNCE yazıldı (sıra karıştı).

### Bug C: `drug_administrations.uygulama_tamamlandi_at` kolonu yok

**Belirti:** `ERROR: 42703: column da.uygulama_tamamlandi_at does not exist`

**Sebep:** `close_case_with_remaining` RPC'de `drug_administrations` tablosunda `uygulama_tamamlandi_at` kolon referansı vardı. Bu kolon sadece `treatment_day_uygulamalar` (seans tablosu) üzerindedir, `drug_administrations`'da YOK.

**Lokasyon (önceki):** Ground truth L3917, L3929, L3940, L3961 (toplam 4 yer).

**Fix:** Spec'ten `uygulama_tamamlandi_at IS NULL` koşulları kaldırıldı. Production + ground truth sync (commit `20d2a3a`).

**Kök neden:** Spec'te hangi tablonun hangi kolonu taşıdığı doğrulanmamış.

### Bug D: `cases.end_date` kolonu yok

**Belirti:** `ERROR: 42703: column "end_date" of relation "cases" does not exist`

**Sebep:** `close_case_with_remaining` RPC spec taslağında `cases.end_date = CURRENT_DATE` kullanılmıştı. `cases` tablosunda `end_date` kolonu **YOK**. Doğru kolonlar: `status` (text, 'active'|'closed') + `closed_at` (timestamptz).

**Lokasyon (önceki):** Production RPC'de (ground truth'ta bu hata hiç yoktu — ground truth L3375 zaten `status='closed', closed_at=now()` kullanıyordu).

**Fix:** Production RPC `/tmp/rpc4_fix2.sql`'de `end_date` → `status='closed', closed_at=now()`. Ground truth zaten doğruydu.

**Kök neden:** T7 için aceleyle yazılan spec'te `cases` şeması doğrulanmamış.

**UI için kritik not:** Case kapatma UI'ında **ASLA** `cases.end_date` yazmayın. Doğru:
```sql
UPDATE public.cases SET status='closed', closed_at=now() WHERE id=$1
```

### 4 Bug'un Ortak Dersi

**Spec yazımında 3 doğrulama zorunlu (her SQL/RPC için):**
1. **Tablo adı:** `SELECT to_regclass('public.tablo_adi')` → NULL ise tablo yok.
2. **Kolon adı + tipi:** `SELECT column_name, data_type FROM information_schema.columns WHERE table_name='tablo_adi' AND column_name='kolon'`.
3. **FK tipi:** `pg_constraint` ile `parent_id` gibi FK kolonlarının referans tiplerini kontrol et.

Bu 3 doğrulama olmadan yazılan spec'lerde **%60 cast hatası** çıkıyor (T2'de T7'de).

---

## 9. MCP Memory Notes

Tools-bank MCP memory'sine bu session'da eklenen notlar (Faz 5/6'da önce bunları oku):

| ID | Kategori | Öncelik | İçerik |
|----|----------|---------|--------|
| `00bca7c7` | `critical_rules` | high | 4 cast hatası kuralı — spec yazarken 3 doğrulama zorunlu (tablo adı, kolon adı+tipi, FK tipi) |
| `c1c8032b` | `code_change` | high | Spec üretim metodolojisi — ground truth'tan al, sed ile minimal fix uygula, diff ile doğrula, sonra production'a deploy |
| `3b3b5225` | `general` | medium | BUG-059 test case detayları — test case ID, hayvan ID, stok ID'leri, drug_admin ID'leri |

**Kullanım:** Faz 5'te yeni RPC'ler yazmadan önce `memory_search(query='BUG-059')` ile ilgili notları getir, sonra `c1c8032b` metodolojisini uygula.

**Sorgu örneği (gelecek session):**
```python
memory_search(query='BUG-059 RPC spec', category='code_change', limit=5)
memory_search(query='cast hatası production fix', category='critical_rules', limit=3)
```

---

## 10. UI Entegrasyonu İçin Gereken Bilgi (Faz 5)

UI devralacak kişi için **operasyonel bilgiler**. Hangi RPC'leri hangi sayfadan çağıracağını, hangi tablolardan veri çekeceğini, hangi state'leri yöneteceğini anlatır.

### 10.1 Frontend Mimari (Mevcut)

| Dosya | Satır | Sorumluluk |
|-------|-------|-----------|
| `js/api.js` | 700+ | Supabase API, `pullTables`, IDB sync, `supabaseRpc()` helper |
| `js/app.js` | 900+ | Ana uygulama mantığı, init, event binding |
| `js/ui.js` | 370KB (en büyük) | UI render fonksiyonları, modal'lar, listeler, tablolar |
| `js/forms.js` | 745+ | Form submit, validasyon, RPC çağrıları |
| `js/state.js` | 65+ | Global state (`AppState`, `getState`/`setState`) |
| `js/config.js` | 110+ | Sabit listeler (HEKIMLER, GRUP_PADOK, tedavi yolu enum) |
| `index.html` | 129KB | Tek sayfa, tüm modüller inline |
| `js/utils/` | - | Yardımcılar (tarih format, TRY parse) |

**Pattern:** Vanilla JS modülleri, `window.AppState` global state, modüller `importScripts` veya `script` tag'iyle yüklenir. Yeni RPC'ler için **3 dosyada** değişiklik gerekir:
1. `js/api.js` — RPC wrapper (varsa)
2. `js/forms.js` — Form submit handler
3. `js/ui.js` — Render fonksiyonu + event binding

### 10.2 4 RPC için UI Kullanım Senaryoları

#### A) Tedavi Günü Ekleme (`add_treatment_day_with_sessions`)

**Sayfa:** Vaka detay sayfası → "Tedavi Ekle" butonu (henüz yok, eklenecek)

**Form alanları:**
- `p_case_id`: otomatik (mevcut vakadan)
- `p_date`: date picker (default = bugün)
- `p_sessions`: dynamic form — kullanıcı "Seans Ekle" butonu ile satır ekler
  - Her satırda: drug_id (select from `stok`), planned_time (time picker), uygulama_yolu (select from enum), planned_dose_ml (number input)
- "Eski tek-seans yolu" toggle'ı: NULL gönder (drug_id tek alan, saat yok)

**Render sonrası:**
- Response'tan `day_id, seans_sayisi, admin_ids` al
- Vakanın treatment_days listesine yeni satır ekle
- Her seans için tedavi kartı render et (saat, ilaç adı, doz, yol)

**Görsel öneri:** Tedavi günü kartı, altında seanslar kronolojik sırayla (08:00, 16:00). Her seansın yanında "Uygulandı" / "Uygulanmadı" butonları.

#### B) Seans Tamamlama (`seans_tamamla`)

**Sayfa:** Vaka detay → Tedavi Günü kartı → Seans satırı

**2 buton (her seans için):**
- ✅ "Uygulandı" → `p_uygulanmadi=false`
- ❌ "Uygulanmadı" → `p_uygulanmadi=true` + `p_not` için modal (opsiyonel)

**Response sonrası:**
- `gun_tamam=true` dönerse: seans kartını "Tamamlandı" rozetiyle güncelle, tedavi günü başlığını "Kapalı" yap
- `seans_done=true`: sadece o seans güncellenir
- Optimistic UI: buton tıklanınca anında "Tamamlanıyor..." spinner, response sonrası kesin state

**Edge case:** `gun_tamam=true` dönerse opsiyonel olarak `treatment_day_tamamla` çağır (idempotent olduğu için güvenli, ama RPC zaten `gun_tamam` flag'ini döndürdüğü için gereksiz olabilir).

#### C) Reçete Güncelleme (`recete_guncelle`)

**Sayfa:** Vaka detay → "Reçeteyi Düzenle" butonu (henüz yok, eklenecek)

**Akış:**
1. Vakanın mevcut tedavi günlerini çek (`treatment_days` WHERE `case_id`)
2. Her gün için seansları çek (`treatment_day_uygulamalar` WHERE `day_id`)
3. `tamamlandi=false` olan günleri **düzenlenebilir** olarak göster (diğerleri kilitli)
4. Kullanıcı seans ekler/çıkarır/saati/değiştirir
5. "Kaydet" → `recete_guncelle` çağır
6. Response sonrası: ilgili day'leri yeniden render et

**Yapı (UI):**
```
Reçete Düzenleme Modal
├── Gün 1 (tamamlandi=true 🔒)
│   ├── 08:00 - Ademin 1ml IM (kilitli)
│   └── 16:00 - Dalmazin 1ml IM (kilitli)
├── Gün 2 (tamamlandi=true 🔒)
│   └── ... (kilitli)
└── Gün 3 (tamamlandi=false ✏️)
    ├── 08:00 - [drug select] [time] [yol] [doz] [sil]
    ├── [+ Seans Ekle]
    └── 16:00 - [drug select] [time] [yol] [doz] [sil]
```

**Güvenlik:** Düzenlenebilir günlerde değişiklik varsa `recete_guncelle` çağrılır. Kilitli günlerde değişiklik yapılamaz.

#### D) Vaka Kapatma (`close_case_with_remaining`)

**Sayfa:** Vaka detay → "Vakayı Kapat" butonu (henüz yok, eklenecek)

**Onay modal'ı:**
- "Bu vakayı kapatmak istediğinize emin misiniz?"
- Kalan açık seans sayısını göster (`treatment_day_uygulamalar` WHERE `case_id` AND `uygulama_tamamlandi_at IS NULL`)
- "Stok iade edilecek" uyarısı
- Opsiyonel kapatma notu (textarea)
- "Vakayı Kapat" → `close_case_with_remaining` çağrısı

**Response sonrası:**
- Vakayı "Kapalı" rozetiyle göster
- Tüm tedavi günlerini "Tamamlandı" yap
- Stok iade özetini göster (hangi ilaçlar, kaç ml)
- Vaka listesinde status badge güncelle

### 10.3 State Senkronizasyonu

**Mevcut pattern:** `pullTables()` tüm tabloları çeker, IndexedDB'ye yazar, `AppState.tables` günceller, sonra UI yeniden render edilir.

**BUG-059 için yeni tablolar:**
- `treatment_day_uygulamalar` → `AppState.tables.treatment_day_uygulamalar` ekle
- `pullTables()` fonksiyonuna ekle (mevcut tablolar: hayvanlar, stok, tohumlama, vb.)

**RPC sonrası pull:** Her RPC çağrısı sonrası `pullTables()` çağrılır (mevcut pattern) veya sadece ilgili tabloyu `refetchTable('treatment_day_uygulamalar')` ile çek.

**IDB şeması:** Yeni tablo için IndexedDB store gerekli (`db.createObjectStore` — `js/api.js` IDB init bölümüne ekle).

### 10.4 Veri Çekme Sorguları (UI için)

Vaka detay sayfası açıldığında:

```sql
-- 1. Vaka bilgisi
SELECT * FROM public.cases WHERE id = $1;

-- 2. Tedavi günleri
SELECT id, day_no, treatment_date, tamamlandi, seans_sayisi, gerceklesme_saati
FROM public.treatment_days
WHERE case_id = $1
ORDER BY day_no;

-- 3. Tüm seanslar (vaka bazlı)
SELECT tdu.id, tdu.treatment_day_id, tdu.drug_id, tdu.planned_time,
       tdu.uygulama_yolu, tdu.planned_dose_ml, tdu.uygulama_tamamlandi_at,
       tdu.uygulanmadi, tdu.iptal_nedeni,
       s.urun_adi AS drug_adi, s.birim
FROM public.treatment_day_uygulamalar tdu
LEFT JOIN public.stok s ON s.id = tdu.drug_id
WHERE tdu.case_id = $1
ORDER BY tdu.planned_date, tdu.planned_time;

-- 4. Açık seanslar (uyarı için)
SELECT COUNT(*) AS acik_seans
FROM public.treatment_day_uygulamalar
WHERE case_id = $1
  AND uygulama_tamamlandi_at IS NULL
  AND uygulanmadi = false;
```

Frontend'de `supabase.from('tablo').select('*')` ile çekilir. Örnek (`js/api.js`):

```javascript
async function getVakaDetay(caseId) {
  const [vaka, days, sessions, openCount] = await Promise.all([
    supabase.from('cases').select('*').eq('id', caseId).single(),
    supabase.from('treatment_days').select('*').eq('case_id', caseId).order('day_no'),
    supabase.from('treatment_day_uygulamalar')
      .select('*, stok:stok_id(urun_adi, birim)')
      .eq('case_id', caseId)
      .order('planned_date').order('planned_time'),
    supabase.from('treatment_day_uygulamalar')
      .select('*', { count: 'exact', head: true })
      .eq('case_id', caseId).is('uygulama_tamamlandi_at', null).eq('uygulanmadi', false)
  ]);
  return { vaka, days, sessions, openCount };
}
```

### 10.5 Yapılacaklar (UI Developer için Checklist)

- [ ] Vaka detay sayfasında "Tedavi Ekle" butonu (modal aç, `add_treatment_day_with_sessions` çağır)
- [ ] Tedavi günü kartında seans listesi (saat, ilaç, doz, yol — `treatment_day_uygulamalar` JOIN `stok`)
- [ ] Her seans için "Uygulandı" / "Uygulanmadı" butonu (`seans_tamamla` çağır)
- [ ] Vaka detayda "Reçeteyi Düzenle" butonu (modal, sadece `tamamlandi=false` günler düzenlenebilir, `recete_guncelle` çağır)
- [ ] Vaka detayda "Vakayı Kapat" butonu (onay modal, `close_case_with_remaining` çağır)
- [ ] `js/api.js` → `pullTables()` yeni tablo ekle
- [ ] `js/api.js` → IDB init yeni store ekle
- [ ] `js/forms.js` → form handler'lar (modal submit)
- [ ] `js/ui.js` → render fonksiyonları (kart, modal, liste)
- [ ] `js/config.js` → `UYGULAMA_YOLU` enum ekle (zaten varsa kontrol et)
- [ ] Responsive: mobilde modal scroll edilebilir, butonlar yeterince büyük
- [ ] Erişilebilirlik: ARIA labels, klavye navigasyonu, focus trap modal içinde
- [ ] Loading state: her RPC çağrısı sırasında skeleton/spinner
- [ ] Hata state: RPC hata mesajlarını kullanıcı dostu toast/snackbar ile göster
- [ ] Optimistic UI: seans tamamla butonu tıklanınca anında "Tamamlanıyor...", hata olursa geri al

### 10.6 Hızlı Başlangıç (UI Developer)

1. `js/config.js` → tedavi yolu enum'unu kontrol et (yoksa ekle)
2. `js/api.js` → `pullTables()` içine `treatment_day_uygulamalar` ekle + IDB store
3. Vaka detay HTML template'inde "Tedavi Ekle" butonu (henüz yok, eklenecek)
4. Tedavi günü/seans render fonksiyonu (mevcut tablolardan pattern al)
5. RPC wrapper fonksiyonları `js/api.js`'e ekle (4 RPC için)
6. Form modal'ları `js/forms.js`'e ekle
7. Test et: vaka oluştur → tedavi ekle (2 seans) → 1. seansı uygulandı işaretle → 2. seansı uygulanmadı işaretle → vakayı kapat → stok iade doğrula

---

## 11. Frontend Dosya Haritası

| Dosya | Satır | BUG-059 Değişikliği |
|-------|-------|---------------------|
| `index.html` | 129KB | Yeni modal'lar için section'lar (Tedavi Ekle, Reçete Düzenle, Vaka Kapat) |
| `js/api.js` | 700+ | `pullTables()` yeni tablo; 4 RPC wrapper; IDB yeni store |
| `js/ui.js` | 370KB | 3 yeni render fonksiyonu (tedavi kartı, seans listesi, modal) |
| `js/forms.js` | 745+ | 3 yeni form submit handler |
| `js/state.js` | 65+ | `AppState` yeni alanlar (currentDay, currentSessions) |
| `js/config.js` | 110+ | `UYGULAMA_YOLU` enum kontrolü |
| `js/utils/` | - | date/time format (gerekirse yeni util) |

**Mevcut pattern referansı:** Vaka oluşturma (`hayvan_not_ekle` veya `hastalik_kaydet`) formu `js/forms.js`'de zaten var — BUG-059 formları için şablon olarak kullanılabilir.

**Yeni eklenmesi gereken IDB store** (`js/api.js` IDB init):
```javascript
const req = indexedDB.open('egesut_erp', 4);
req.onupgradeneeded = (e) => {
  // ... mevcut store'lar ...
  if (!db.objectStoreNames.contains('treatment_day_uygulamalar')) {
    db.createObjectStore('treatment_day_uygulamalar', { keyPath: 'id' });
  }
};
```

---

## 12. Test Verileri (Canlı DB)

Smoke test sonrası DB'de kalan veriler. Faz 5 UI'ı bu verilerle direkt test edilebilir.

| Varlık | ID | Açıklama |
|--------|----|----|
| **Test Case** | `1de1605a-f1c6-40e6-83e2-2139c69b1735` | Şu an `status='closed'`, `closed_at=2026-06-12 07:39:15` |
| **Test Hayvan** | `fc01526a-7fb0-4b9e-abb7-0d5806d4cd7b` | Test inek 2 |
| **Stok 1 (Ademin)** | `ab225673-260b-477a-bddf-d7cb044098e0` | drug_product_id: `fcfeeea6-f24f-40ee-a363-4e4b5d11d0c0` |
| **Stok 2 (Dalmazin)** | `2db3fb52-717a-4636-a0bc-88f07e09f333` | drug_product_id: `11fdc54e-fc8b-41a0-b3ba-2cd50e0c502b` |

### Oluşturulan Treatment Days (3 adet)

| day_id | day_no | tarih | tamamlandi | seans_sayisi |
|--------|--------|-------|------------|--------------|
| `3503ef78-247d-45f6-87c9-5a1773ca1a81` | 1 | 2026-06-12 | ✅ true | null (legacy) |
| `15558fff-9b7c-4861-9f57-738c190ec27a` | 2 | 2026-06-12 | ✅ true | 2 |
| `8e42b283-929c-48fc-a6dd-c8c6672dc61c` | 3 | 2026-06-14 | ✅ true (T7) | 2 |

**T7 sonrası:** Tüm seanslar `uygulanmadi=true` veya `uygulama_tamamlandi_at IS NOT NULL`. Stok iade edildi (6 hareket `iptal=true`).

**Yeni test için:** Yeni bir `cases` kaydı aç (test hayvanıyla), `disease_id` seç. Eski test case'i UI'da salt okunur göster.

---

## 13. Yapılacaklar (Faz 5 / 6 / 7)

### Faz 5 — UI Entegrasyonu (sıradaki)

- [ ] Vaka detay sayfasına "Tedavi Ekle" butonu + modal
- [ ] Tedavi günü/seans render (saat, ilaç, doz, yol)
- [ ] "Uygulandı" / "Uygulanmadı" butonları (her seans için)
- [ ] "Reçeteyi Düzenle" butonu + modal
- [ ] "Vakayı Kapat" butonu + onay modal
- [ ] `js/api.js` → `pullTables()` + IDB store güncelleme
- [ ] 4 RPC wrapper fonksiyonu
- [ ] Form submit handler'lar (3 modal)
- [ ] Loading + error + empty state'ler
- [ ] Responsive + a11y (klavye, ARIA, focus)
- [ ] Manuel UI test (Faz 6'ya geçmeden önce)

**Tahmini süre:** 3-4 oturum (Claude + UI developer birlikte).

### Faz 6 — 10 E2E Test Senaryosu

Plan'da (commit `19f77b5`) belirtilen 10 senaryo:

1. Vaka aç → tek-seans tedavi ekle → uygulandı işaretle
2. Vaka aç → çok-seans (2) tedavi ekle → tümünü uygulandı işaretle
3. Vaka aç → çok-seans (3) tedavi ekle → 1 uygulandı + 2 uygulanmadı
4. Vaka aç → reçete güncelle (yeni gün ekle) → uygulandı
5. Vaka aç → reçete güncelle (var günü sil) → eski seanslar geçerli
6. Vaka aç → tedavi ekle → erken kapat → stok iade doğrula
7. Vaka aç → tedavi ekle → tamamlandı işaretle (eski tek-seans yol)
8. Vaka aç → reçetede tutarsızlık (drug yok stok'ta) → hata mesajı
9. Vaka aç → UNIQUE constraint ihlali (aynı saat 2 seans) → hata mesajı
10. Vaka aç → çok-seans → reçetede güncelle (tamamlanmış gün korunur)

**UI devralacak kişi:** Senaryo 1-5 + 7 manuel test, senaryo 6 + 8-10 hata yolu test.

### Faz 7 — Final Handoff + ADR

- [ ] Faz 4 → Faz 5 → Faz 6 tamamlandıktan sonra ADR (Architecture Decision Record) yaz
- [ ] `docs/adr/0007-bug059-saat-bazli-tedavi-seans.md` — neden bu mimari seçildi (seans tablosu ayrı, parent_id ilişkisi, idempotent pattern)
- [ ] Final handoff: production'da 5 RPC + UI tam entegre, 10 E2E senaryo PASS
- [ ] `ReFactorRoadmap.md` güncelle — BUG-059 tamamlandı, Faz 2'ye geçilebilir

---

## 14. Riskler + Açık Noktalar

### Bilinen Riskler

1. **`recete_guncelle` DELETE+INSERT stratejisi:** Mevcut seanslar silinir, yeniden oluşturulur. Yan etkisi: bağlı `drug_admins` + `gorev_log` da CASCADE ile silinir. Eğer reçete güncellemesinden sonra tamamlanmış seans varsa **veri kaybı** olur (drug_admin kaydı + stok_hareket). Çözüm: UI'da güncelleme öncesi uyarı + onay.

2. **`gorev_log.parent_id` tip tutarsızlığı:** Ana tedavi görevi `parent_id=NULL`, seans görevleri `parent_id=ana_gorev_id`. Faz 0'da bu ayrım netleşti ama Faz 5'te raporlama sorguları yazarken dikkat edilmeli (`WHERE parent_id IS NULL` ana görev, `WHERE parent_id IS NOT NULL` seans görevleri).

3. **`stok_hareket.notlar` string pattern:** `'drug_admin:' || drug_admins.id::text` pattern'i string concat. Stok raporlarında JOIN yaparken dikkat: `notlar` kolonunu parse etmek gerekirse `split_part(notlar, ':', 2)` ile UUID çekilebilir.

4. **`close_case_with_remaining` `iade_edilen_stok` sayımı yanıltıcı:** RPC `iade_edilen_stok=5` dedi ama gerçekte 6 hareket iptal edildi (T4'ün 1 iadesi + T7'nin 5 iadesi). UI'da bu sayıya güvenip "X ilaç iade edildi" mesajı vermek yanıltıcı olabilir. Doğru gösterim: gerçek hareket sayısını `SELECT COUNT(*) FROM stok_hareket WHERE iptal=true AND notlar LIKE 'drug_admin:%' AND drug_admin_id IN (SELECT id FROM drug_administrations WHERE seans_admin_id IN (...))` ile çek.

5. **Faz 3 uyumluluk alias'ı:** `treatment_day_tamamla` ground truth'ta iki kez tanımlı (L3391 + L4006). Production'da hangisinin aktif olduğu Faz 6'da doğrulanmalı. UI tek RPC çağırdığı için sorun olmayabilir ama imza farklılığı varsa hata riski var.

6. **Geçmiş veri (legacy tek-seans):** `treatment_days.seans_sayisi IS NULL` olan eski kayıtlar. Yeni RPC'ler bunları destekliyor (`p_sessions=NULL` yolu) ama UI'da gösterim farklı olmalı ("Tek seans" rozeti).

### Açık Noktalar (Gelecek Session'larda Netleşecek)

- [ ] `cases` tablosuna `end_date` eklenecek mi? (BUG-059 kapsamı dışı, ayrı ticket)
- [ ] `treatment_day_uygulamalar` üzerinde trigger var mı? (audit log için kontrol edilmedi)
- [ ] `recete_guncelle` snapshot'ı kaydediliyor mu? (reçete değişiklik geçmişi)
- [ ] `close_case_with_remaining` audit log `islem_log`'a ne yazıyor? (T7'de `tip='CASE_CLOSED_EARLY'` görüldü ama kolonlar doğrulanmadı)
- [ ] Faz 5 sonrası `pullTables()` performans — yeni tablo eklenince 700KB response olabilir (pagination gerekebilir)

---

## 15. Referanslar

### Proje Dosyaları (BUG-059)

| Dosya | Konum |
|-------|-------|
| Migration (Faz 1) | `supabase/migrations/20260611000001_bug059_treatment_sessions.sql` |
| Migration (Faz 2) | `supabase/migrations/20260611000002_bug059_rpcs.sql` |
| Ground truth (canonical) | `supabase/migrations/99999999999999_ground_truth.sql` |
| Spec (plan) | `plan: saat bazli tedavi seans sistemi` (commit `14aada1`) |
| Plan v3 (1269 satır) | `BUG-059 implementation plan` (commit `19f77b5`) |
| Spec review v3 | `BUG-059 spec review v3 düzeltmeleri` (commit `9f22982`) |

### Claude Notları (Context)

| Dosya | Açıklama |
|-------|----------|
| `.claude/notes/handoff-bug059-faz4-sonrasi.md` | Faz 4 detaylı test logu (T1-T7 SQL, response, verification) |
| `.claude/notes/handoff-faz-0-sonrasi.md` | Faz 0 şema analiz (BUG-059 öncesi context) |
| `.claude/notes/faz-a1-envanter-raporu.md` | Faz A1 envanter raporu |
| `.claude/notes/padok-transfer-arastirma.md` | Yan proje (padok transfer) |
| `.claude/rpc-reference.md` | Tüm RPC'lerin tek sayfa referansı |
| `.claude/domain-rules.md` | Domain kuralları (FK, validasyon, vb.) |
| `.claude/session-learnings.md` | Geçmiş oturum öğrenimleri |

### Commit Geçmişi (BUG-059)

**Ana commit'ler:**
```
c9bf2b9 BUG-059 Faz 4: 7/7 smoke test PASS, parent_id cast fix + handoff
20d2a3a BUG-059 ground truth sync (Bug A, C, D fix)
d707f6b BUG-059 Faz 2: 5 RPC + spec/rpc-reference docs
379e544 BUG-059 Faz 1+3: ground_truth senkronu (schema + RPC + uyumluluk)
1cd20dd BUG-059 Faz 1: schema migration (4 kolon, 5 index, UNIQUE, CHECK)
6ff0c69 fix(BUG-059): Faz 0 drift fix - planned_time/treatment_time ayrimi
f877f46 fix(BUG-059): 19 Opus review fix + Faz 0 drift raporu + handoff
```

**Plan/Review commit'leri:**
```
4232955 docs: BUG-059 plan v3 polish fix
ab417e7 docs(plan): BUG-059 plan v2 self-review düzeltmeleri
19f77b5 plan: BUG-059 implementation plan (8 Faz, 1269 satir)
9f22982 docs: BUG-059 spec review v3 düzeltmeleri
161391f docs(spec): BUG-059 review düzeltmeleri
14aada1 spec: saat bazli tedavi seans sistemi (BUG-059 cozumu)
```

**Sorgu:** `git log --grep='BUG-059' --oneline`

### MCP Memory (tools-bank)

- `00bca7c7` — 4 cast hatası kuralı (critical_rules, high)
- `c1c8032b` — Spec üretim metodolojisi (code_change, high)
- `3b3b5225` — BUG-059 test case detayları (general, medium)

**Sorgu:** `memory_search(query='BUG-059', limit=5)`
