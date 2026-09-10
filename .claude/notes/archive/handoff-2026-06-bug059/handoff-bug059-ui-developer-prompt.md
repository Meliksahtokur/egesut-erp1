# BUG-059 — UI Developer Geçiş Promptu (Saat Bazlı Tedavi Seans Sistemi)

> **Bu dosya:** Yeni AI agent'a (veya AI destekli UI geliştiriciye) **doğrudan verilecek** metin. Kopyala-yapıştır, gerekirse `<placeholder>`'ları doldur.
> **Uzunluk:** ~200 satır (hızlı okuma için, detay için `.claude/notes/handoff-bug059-final.md` referans).
> **Durum:** DB katmanı (Faz 0-4) hazır ve **7/7 smoke test PASS**. UI entegrasyonu (Faz 5) + E2E testler (Faz 6) bekliyor.
> **Güncelleme:** 2026-06-12 — Bug A, C, D hepsi fix edildi, T7 doğrulandı, working tree clean.

---

## 1. Görevin (Tek Cümle)

EgeSüt ERP'ye **saat bazlı tedavi seans yönetimi** UI'ı ekle. Backend (5 PostgreSQL RPC + 1 yeni tablo + 4 kolon değişikliği) hazır, production'da, smoke test geçti. Senin işin: 4 RPC'yi çağıran **3 modal** (Tedavi Ekle, Reçete Düzenle, Vaka Kapat) + seans tamamlama butonları + render katmanı.

---

## 2. Proje Hakkında Bilmen Gereken 10 Şey

| # | Bilgi |
|---|-------|
| 1 | **Proje:** EgeSüt ERP — süt hayvancılığı yönetim sistemi. Stack: Vanilla JS + Supabase (PostgreSQL) + GitHub Pages (CDN-only, **no bundler**). |
| 2 | **Çalışma dizini:** `/root/egesut-erp1` (veya kendi clone'un). Branch: `main`. Push direkt. |
| 3 | **Frontend dosyaları:** `index.html` (129KB tek sayfa), `js/api.js` (700+ satır, Supabase), `js/ui.js` (370KB, render), `js/forms.js` (745+, form), `js/state.js` (65+ global state), `js/config.js` (110+ enum/sabit). |
| 4 | **State pattern:** `window.AppState` global, `getState`/`setState` helper'ları. IDB cache (`egesut_erp` DB, version 4). |
| 5 | **Pattern:** Tüm modüller `script` tag'iyle yüklenir (ES module değil). `innerHTML = template literal` ile render. Vanilla JS — React/Vue/YOK. |
| 6 | **Mimari kural:** Business logic DB'de. Frontend sadece input alır → RPC çağırır → response render eder. State senkronizasyonu `pullTables()` ile. |
| 7 | **API çağrı pattern:** `supabase.from('tablo').select('*').eq(...)` (SELECT) veya `supabase.rpc('rpc_name', { p_param: val })` (RPC). Mevcut `js/api.js` → `supabaseRpc()` helper. |
| 8 | **GitHub Pages deploy:** `main` branch'e push → otomatik deploy. Supabase SQL ayrıca deploy edilmeli (`supabase_migrate` MCP tool). Migration dosyası repoda olması = canlıda çalışıyor DEĞİL. |
| 9 | **Test ortamı:** Canlı Supabase (production DB). Test case: `1de1605a-f1c6-40e6-83e2-2139c69b1735` (open), test hayvan: `fc01526a-7fb0-4b9e-abb7-0d5806d4cd7b`. Yeni test için yeni `cases` kaydı aç. |
| 10 | **Dil:** Türkçe UI (anadil kullanıcı). İngilizce sadece kod/migration yorum/değişken adlarında. |

---

## 3. 4 RPC — Ne İş Yapıyor, Ne Zaman Çağrılır

| # | RPC | Amaç | Ne Zaman Çağır |
|---|-----|------|----------------|
| 1 | `add_treatment_day_with_sessions(p_case_id, p_date, p_sessions, p_existing_day_id?)` | Yeni tedavi günü + seanslar (eski tek-seans yol: `p_sessions=NULL`) | "Tedavi Ekle" butonu |
| 2 | `seans_tamamla(p_seans_admin_id, p_uygulanmadi, p_not?)` | Tek seansı tamamlandı/yapılamadı işaretle + stok düş/iade | "Uygulandı" / "Uygulanmadı" butonu |
| 3 | `recete_guncelle(p_case_id, p_yeni_plan)` | Reçetedeki günleri güncelle (sadece `tamamlandi=false` olanlar) | "Reçeteyi Düzenle" → Kaydet |
| 4 | `close_case_with_remaining(p_case_id, p_not?)` | Vakayı erken kapat, kalan seansları iptal et, stok iade | "Vakayı Kapat" → Onay |

**5. RPC:** `treatment_day_tamamla(p_day_id, p_not?)` — opsiyonel, RPC 2 zaten `gun_tamam` döndürüyor, genelde gerek yok. İdempotent.

**Her RPC'nin imzası, argüman açıklaması, response yapısı, idempotent kuralları, edge case'leri:**
→ `.claude/notes/handoff-bug059-final.md` §4.1-4.5 (her RPC için tam döküm).

---

## 4. Yeni Şema (Ne Değişti)

### Yeni tablo: `treatment_day_uygulamalar`

Her seans = 1 satır. **Senin ana veri kaynağın.**

```sql
id uuid PK, treatment_day_id uuid FK, case_id uuid FK, drug_id uuid FK (stok),
planned_date date, planned_time time, uygulama_yolu text (IM/IV/SC/PO/IM/IV/Diğer),
planned_dose_ml numeric, applied_dose_ml numeric NULL,
uygulama_tamamlandi_at timestamptz NULL, uygulanmadi boolean DEFAULT false,
iptal_nedeni text NULL, created_at, updated_at
```

UNIQUE: `(treatment_day_id, planned_time)`. 5 index var (hızlı sorgu için).

### Değişen tablolar

- `treatment_days`: +2 kolon (`seans_sayisi int NULL`, `gerceklesme_saatti time NULL`)
- `cases`: +1 kolon (`closed_at timestamptz NULL`) — **`end_date` YOK**, case kapatma için `status='closed', closed_at=now()` kullan
- `drug_administrations`: +1 kolon (`seans_admin_id uuid NULL FK`) — **`uygulama_tamamlandi_at` kolonu YOK** (bu seans tablosunda)
- `drug_admins` → `drug_administrations` (rename edildi, eski adı ASLA kullanma)

**Detay + 5 index + CHECK constraint + drift notu:**
→ `.claude/notes/handoff-bug059-final.md` §3 (her kolon için).

---

## 5. Yapılacaklar (UI Checklist)

### Dosya bazında:

| Dosya | Değişiklik |
|-------|-----------|
| `js/api.js` | `pullTables()` yeni tablo ekle; 4 RPC wrapper fonksiyonu; IDB init yeni store |
| `js/ui.js` | 3 yeni render fonksiyonu (tedavi kartı, seans listesi, modal) |
| `js/forms.js` | 3 yeni form submit handler |
| `js/state.js` | `AppState` yeni alanlar (currentDay, currentSessions, editingPlan) |
| `js/config.js` | `UYGULAMA_YOLU` enum kontrolü (yoksa ekle) |
| `index.html` | 3 yeni modal template (Tedavi Ekle, Reçete Düzenle, Vaka Kapat) |

### Sayfa bazında:

- [ ] **Vaka detay sayfası** (mevcut) → "Tedavi Ekle" butonu ekle
- [ ] **Tedavi günü kartı** (yeni) → seans listesi (saat, ilaç, doz, yol)
- [ ] **Seans satırı** (yeni) → "Uygulandı" + "Uygulanmadı" butonları
- [ ] **"Reçeteyi Düzenle"** modal → sadece `tamamlandi=false` günler düzenlenebilir
- [ ] **"Vakayı Kapat"** modal → onay + kapatma notu

### 10 E2E senaryosu (Faz 6, sonra):

1. Tek-seans tedavi → uygulandı
2. Çok-seans (2) → tümü uygulandı
3. Çok-seans (3) → 1 uygulandı + 2 uygululanmadı
4. Reçete güncelle (yeni gün ekle)
5. Reçete güncelle (var günü sil — diff değil full replace)
6. Erken kapat → stok iade doğrula
7. Tamamlandı işaretle (eski tek-seans yol)
8. UNIQUE constraint (aynı saat 2 seans) → hata
9. Tutarsız reçete (drug yok stok'ta) → hata
10. Çok-seans → reçetede güncelle (tamamlanmış gün korunur)

**Detay + Checklist + hızlı başlangıç:**
→ `.claude/notes/handoff-bug059-final.md` §10.5, §10.6.

---

## 6. Yapma! Yasaklar (KRİTİK)

1. **`cases.end_date` ASLA kullanma** — kolon yok. `UPDATE cases SET status='closed', closed_at=now()` kullan.
2. **`drug_admins` ASLA kullanma** — eski ad. `drug_administrations` kullan.
3. **`drug_administrations.uygulama_tamamlandi_at` ASLA kullanma** — kolon yok (seans tablosunda). Seans tamamlanma kontrolü `treatment_day_uygulamalar.uygulama_tamamlandi_at` üzerinden.
4. **Raw SQL string concat YASAK** — `supabase.rpc()` veya fetch API kullan.
5. **`main` dışında branch — YASAK**. Direkt commit + push.
6. **CLAUDE.md / AGENTS.md değiştirme — YASAK** (Claude yönetir).
7. **Yeni RPC yazmadan önce** `handoff-bug059-final.md` §4.1-4.5'i oku, mevcut RPC'leri kontrol et (duplikat olmasın).
8. **`npx playwright test` local — YASAK** (PRoot'ta CPU krizi yapar). CI'da otomatik çalışır.
9. **Migration dosyası repoda olması = canlıda çalışıyor DEĞİL**. DB değişiklikleri `supabase_migrate` MCP ile ayrıca deploy et.

---

## 7. Dersler (Geçmiş Hatalardan Öğren)

| Ders | Detay |
|------|-------|
| **Spec yazarken 3 doğrulama zorunlu** | `to_regclass` (tablo var mı), `information_schema.columns` (kolon adı+tipi), `pg_constraint` (FK tipi). Yapmazsan cast hatası alırsın. |
| **Ground truth canonical** | `supabase/migrations/99999999999999_ground_truth.sql` (10.780 satır). Ara migration'lar (`*_revize`, `*_fix`) şüpheli, referans ALMA. |
| **Idempotent RPC** | Frontend'de buton 2 kez tıklanabilir. RPC "zaten tamam" state'inde hata fırlatmamalı, `step='zaten_tamam'` dönmeli. |
| **`gorev_log.parent_id` ayrımı** | Ana tedavi görevi `parent_id=NULL`, seans görevleri `parent_id=ana_gorev_id`. Raporlama sorgularında `WHERE parent_id IS NULL` (ana) / `IS NOT NULL` (seans). |
| **`stok_hareket.notlar` pattern** | `'drug_admin:' || drug_admins.id::text`. Parse: `split_part(notlar, ':', 2)::uuid`. JOIN için bu pattern'i kullan. |
| **Ground truth da bug'lı olabilir** | BUG-059'da 3 bug hem production hem ground truth'ta vardı (A: cast, C: kolon adı, D: end_date). Spec yazarken her kolonu doğrula. |

**Detay:** `.claude/session-learnings.md` (2026-06-12 oturumu, 6 pattern).

---

## 8. Sık Kullanılacak Sorgu Şablonları

### Vaka detay açıldığında çekilecek veriler:

```js
// 1. Vaka bilgisi
supabase.from('cases').select('*').eq('id', caseId).single()

// 2. Tedavi günleri
supabase.from('treatment_days').select('*').eq('case_id', caseId).order('day_no')

// 3. Tüm seanslar (JOIN stok ile)
supabase.from('treatment_day_uygulamalar')
  .select('*, stok:stok_id(urun_adi, birim)')
  .eq('case_id', caseId)
  .order('planned_date').order('planned_time')

// 4. Açık seanslar (Vaka Kapat uyarısı için)
supabase.from('treatment_day_uygulamalar')
  .select('*', { count: 'exact', head: true })
  .eq('case_id', caseId)
  .is('uygulama_tamamlandi_at', null)
  .eq('uygulanmadi', false)
```

### RPC çağrısı:

```js
// Tedavi günü + 2 seans ekle
const result = await supabase.rpc('add_treatment_day_with_sessions', {
  p_case_id: caseId,
  p_date: '2026-06-15',
  p_sessions: [
    { drug_id: 'ab225673-...', planned_time: '08:00', uygulama_yolu: 'IM', planned_dose_ml: 1 },
    { drug_id: '2db3fb52-...', planned_time: '16:00', uygulama_yolu: 'IM', planned_dose_ml: 1 }
  ]
});
// result.seans_sayisi === 2, result.admin_ids.length === 2
```

---

## 9. İlk Yapacağın 3 Şey (Sırasıyla)

1. **Handoff'un tamamını oku** (871 satır): `.claude/notes/handoff-bug059-final.md`. Bu prompt sadece özet — detay orada.
2. **Mevcut UI pattern'i incele**: `js/forms.js` → mevcut "Hastalık Ekle" veya "Tedavi Ekle" (eski tek-seans) formu nasıl yazılmış? Şablon olarak kullan.
3. **Küçük başla**: İlk modal = "Tedavi Ekle" (1 form, 1 RPC çağrısı, 1 render). Çalışınca diğerlerine geç.

---

## 10. Sorun Olursa

| Sorun | Çözüm |
|-------|-------|
| Cast hatası (42804) | `information_schema.columns` ile kolon tipini kontrol et, düzelt |
| Tablo yok (42P01) | `to_regclass('public.tablo')` ile var mı bak, eski ad kullanma |
| "Beklemediğim davranış" | Önce mevcut RPC signature'ını `pg_proc` üzerinden doğrula (psql veya supabase rpc info) |
| Performans sorunu | `treatment_day_uygulamalar` üzerinde 5 index var; `pullTables()` sonrası tüm tablo çekiliyor, gerekirse sayfalama ekle |
| Unclear case | Claude'a sor + `.claude/notes/handoff-bug059-final.md` referans ver |

---

## 11. Referanslar (Hızlı Link)

| Dosya | Ne İçin |
|-------|---------|
| `docs/superpowers/specs/2026-06-12-bug059-ui-design-klinisyen-monitoru.md` | **UI TASARIM SPESİFİKASYONU** (Klinisyen Monitörü estetiği — renkler, tipografi, EKG ribbon, 4 modal sketch, state matrisi) |
| `.claude/notes/handoff-bug059-final.md` | **ANA REFERANS** (871 satır, 15 section) |
| `.claude/notes/handoff-bug059-faz4-sonrasi.md` | Faz 4 özet, test matrisi, bug fix chronology |
| `.claude/notes/handoff-faz-0-sonrasi.md` | Faz 0 plan, planned_time/treatment_time ayrımı |
| `.claude/session-learnings.md` | Bu oturumdaki 6 pattern (güncellenmiş) |
| `supabase/migrations/99999999999999_ground_truth.sql` | Canonical DB state (10.780 satır) |
| `supabase/migrations/20260611000002_bug059_rpcs.sql` | BUG-059 RPC migration (5 RPC) |
| `.claude/rpc-reference.md` | Tüm RPC imzaları (BUG-059 dahil) |
| `docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md` | DB kontratı (T7 doğrulandı) |
| `js/forms.js` → mevcut "Tedavi Ekle" formu | UI pattern şablonu |
| `js/api.js` → `supabaseRpc()` helper | RPC çağrı şablonu |

---

## 12. Durum Snapshot (2026-06-12)

| Öğe | Durum |
|---|---|
| Aktif bug | **0** (Bug A, C, D hepsi fix edildi) |
| Faz 0/1/2/3 | ✅ Deploy + push |
| Faz 4 smoke test | **7/7 ✅ PASS** (T1-T7 hepsi geçti, stok iade doğrulandı) |
| Faz 5 (UI) | ⏳ Bekliyor — bu görev |
| Faz 6 (E2E) | ⏳ Bekliyor — bu görev sonrası |
| Faz 7 (Handoff) | ⏳ Bekliyor — final ADR |
| Working tree | **clean** |
| Son commit | `961ea04` (main, push edildi) |

### Commit Zinciri (BUG-059 final)
```
961ea04 docs: BUG-059 final handoff (871 satır) + session learnings  ← son
f51a7e3 docs(BUG-059): final handoff - Faz 0'dan Faz 4'e tam ozet
ea7023d fix(BUG-059): ground truth Bug A sync - v_gorev_id::text cast kaldirildi
c9bf2b9 BUG-059 Faz 4: 7/7 smoke test PASS, parent_id cast fix + handoff
d707f6b BUG-059 Faz 2: 5 RPC + spec/rpc-reference docs
379e544 BUG-059 Faz 1+3: ground_truth senkronu
1cd20dd BUG-059 Faz 1: schema migration (4 kolon, 5 index, UNIQUE, CHECK)
6ff0c69 fix(BUG-059): Faz 0 drift fix
f877f46 fix(BUG-059): 19 Opus review fix
```

### Test Verileri (T0 ✅)
- **Test case ID:** `1de1605a-f1c6-40e6-83e2-2139c69b1735` (status: open)
- **Hayvan:** `fc01526a-7fb0-4b9e-abb7-0d5806d4cd7b` (Test inek 2)
- **Stok 1:** Ademin (drug_product_id: `fcfeeea6-...`) — yeterli miktar kaldı
- **Stok 2:** Dalmazin (drug_product_id: `11fdc54e-...`) — yeterli miktar kaldı
