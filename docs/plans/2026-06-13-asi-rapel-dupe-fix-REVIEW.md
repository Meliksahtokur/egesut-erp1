# Review — Aşı 2. Doz Duplicate Fix (migration + tasarım)

> **Reviewer:** Claude (Opus 4.8)
> **Tarih:** 2026-06-13
> **İncelenen:**
> - `docs/plans/2026-06-13-asi-rapel-dupe-fix-design.md`
> - `supabase/migrations/20260613000001_asi_rapel_dupe_fix.sql`
> **Yöntem:** Tasarım + migration satır satır okundu, **canlı DB** `supabase_migrate`/`supabase_query` ile doğrulandı (fonksiyon gövdeleri, gerçek kayıtlar, hayvan durumları).
> **Sonuç:** ⛔ **Bu migration mevcut hâliyle ÇALIŞTIRILMAMALI.** Biri kesin (migration abort), biri mantıksal olmak üzere 2 blocker var; hedeflediği bug'ı (küpe 184'ün fazla görevi) **çözmüyor**.

---

## 0. TL;DR

| # | Bulgu | Şiddet | Etki |
|---|-------|--------|------|
| **B1** | `ileri_gebe_asi_tamamla` migration'da `RETURNS json`, canlıda `RETURNS jsonb` | ⛔ **BLOCKER** | `CREATE OR REPLACE` → `cannot change return type of existing function` → **tüm migration rollback** |
| **B2** | Backfill `AND etken_kod IS NULL` koşulu, tamamlanmış 2. doz kayıtlarını (canlıda `etken_kod='ROTA'`) atlıyor | ⛔ **BLOCKER (mantık)** | Cleanup'ın dayandığı "legit" kayıt `ROTA_2DOZ` olmuyor → **temizlik 0 kayıt iptal ediyor**, küpe 184'ün stray görevi (`16de0128`) **silinmiyor**. Tasarımın "2 iptal" beklentisi yanlış. |
| **B3** | `gebelik_protokol_kontrol` 261 dedup'una `tamamlandi=false` eklendi; eski kod yoktu | ⚠️ **Yüksek (latent)** | Tamamlanmış 2. doz'u `ROTA` etiketli olan + hâlâ 261+ Düve penceresinde olan hayvana **yeni sahte görev üretir**. Şu an canlıda tetikleyen hayvan yok ama kırılgan. İki fonksiyon arasında tutarsız (`ileri_gebe_gorev_kontrol`'de yok). |
| N1 | 2. doz → `etken_kod='ROTA_2DOZ'` dinleme trigger'ından (`_etken_kod_bul`→'ROTA') kopuyor | ℹ️ Düşük | Genel aşı modalından uygulanırsa auto-close olmaz. Pratikte 2. doz buton→`ileri_gebe_asi_tamamla` (ID ile kapatır) yoluyla kapanıyor; **regresyon değil** (önceden de NULL idi). |
| N2 | `ON CONFLICT (cols) WHERE ... DO NOTHING` partial-index inference | ℹ️ Düşük | Doğru kullanım; INSERT `iptal` set etmiyor ama default=false olduğundan predicate tutuyor. Sorun yok. |
| **N3** | JS `_katTipMap` (`js/ui.js:946`) `'ROTA'` içeriyor ama `'ROTA_2DOZ'` **yok** | ⚠️ Orta (kırılgan) | `detayTamamla()` (ui.js:4037) `etken_kod && !stok_id` ise `_etkenFiltrele(etken_kod)`'a gider. 2. doz görevi stok_id **taşıdığı** için şu an dal atlanıyor → patlamıyor. Ama Rota aşısının `stock_item_id`'si NULL olursa → "uygun stok bulunamadı" → görev kapatılamaz. **Sigorta:** `_katTipMap`'e `'ROTA_2DOZ': /rota|corona/i` ekle. |

**Net karar:** Fikir (semantic key + UNIQUE partial index) doğru ve geleceğe yönelik sağlam. Ama migration **canlı verinin gerçeğiyle uyuşmuyor** — "2. doz kayıtları `etken_kod IS NULL`" varsayımı **yanlış**. Tamamlanmış kayıtlar `ROTA` taşıyor. Bu yüzden hem teknik (B1) hem mantıksal (B2) olarak başarısız.

---

## 1. Canlı DB Kanıtı (bugün, 2026-06-13)

### 1.1 Aktif (iptal=false) "2. doz" kayıtlarının GERÇEK hâli

| id | hayvan (küpe) | tamamlandi | parent_id | **etken_kod** |
|---|---|---|---|---|
| `16de0128` | e61f6151 (**184**) | false | NULL | **null** ← stray aktif görev |
| `2caf290b` | e61f6151 (**184**) | true | dda9dbcb | **ROTA** ← gerçek tamamlanmış 2. doz |
| `16b8513b` | bcc67af7 (168) | true | NULL | **ROTA** |
| `3f1759ad` | bcc67af7 (168) | true | 43f09bca | **ROTA** |

> ⚠️ Tasarım §1.1 ve migration §1 "2. doz kayıtları `etken_kod IS NULL`" diyor. **GERÇEK: sadece stray scheduler kaydı (`16de0128`) NULL; tamamlanmış olanlar `ROTA`.** (Geçmiş bir backfill tüm Rota görevlerini aciklama'dan `ROTA` etiketlemiş — 1. doz da 2. doz da `ROTA`.)

### 1.2 Hayvan durumları

| küpe | id | grup | durum | son Gebe toh | gebelik gün |
|---|---|---|---|---|---|
| 184 | e61f6151 | **Gebe Düve** | Aktif | 2025-09-24 | **262** (261+ ✅) |
| 168 | bcc67af7 | Sağmal (Laktasyonda) | Aktif | **null** (doğurmuş) | — |

- **184** hâlâ 261+ Düve penceresinde → stray görev canlı, temizlenmeli.
- **168** doğum yapmış, gebe döngüsünde değil → ne stray ne regresyon tetikliyor.

### 1.3 Canlı fonksiyon imzaları (doğrulandı)

- `ileri_gebe_asi_tamamla(text,uuid,date,numeric)` → **`RETURNS jsonb`** (migration: `json` ❌)
- `gebelik_protokol_kontrol()` / `ileri_gebe_gorev_kontrol()` gövdeleri migration'daki "değişmeyen bloklar" ile **birebir uyuşuyor** → tam-rewrite riski düşük (bu kısım sağlam). Canlı 261 blokları `etken_kod` set **etmiyor** (NULL üretiyor).

---

## 2. Blocker Detayları

### B1 — Return type değişimi → migration abort (kesin)

Migration satır 76-81:
```sql
CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(...)
RETURNS json   -- ❌ canlı: jsonb
```
PostgreSQL kuralı: `CREATE OR REPLACE FUNCTION` **dönüş tipini değiştiremez**. Hata:
```
ERROR: cannot change return type of existing function
HINT: Use DROP FUNCTION ... first.
```
Migration `BEGIN; ... COMMIT;` içinde olduğundan **tüm migration geri alınır** (backfill, index, cleanup dahil hiçbiri uygulanmaz).

**Düzeltme:** Ya migration'ı `RETURNS jsonb` + `jsonb_build_object` yap (canlıyla aynı — tercih edilen, en az sürpriz), ya da fonksiyonu önce `DROP FUNCTION` et (riskli: GRANT'lar düşer, bağımlılık). → **`jsonb` yap.** İçindeki `v_vax_result json` da `jsonb` olmalı.

### B2 — Backfill tamamlanmış kayıtları atlıyor → cleanup no-op (mantıksal)

Migration §1:
```sql
UPDATE gorev_log SET etken_kod='ROTA_2DOZ'
WHERE gorev_tipi='ILERI_GEBE_ASI' AND aciklama ILIKE '%Rota-Corona%2. doz%'
  AND etken_kod IS NULL;          -- ⛔ sorun burada
```
Canlıda tamamlanmış 2. doz kayıtları `etken_kod='ROTA'` (NULL değil) → **backfill onları atlar**, `ROTA` kalırlar.

Sonra cleanup §6:
```sql
... AND EXISTS (SELECT 1 FROM gorev_log legit
      WHERE legit.hayvan_id=uzak.hayvan_id
        AND legit.etken_kod='ROTA_2DOZ'   -- legit'in ROTA_2DOZ olması gerek
        AND legit.parent_id IS NOT NULL AND legit.iptal=false);
```
Küpe 184 için: `uzak`=`16de0128` (backfill ile `ROTA_2DOZ` ✓). Ama legit aday `2caf290b` parent dolu ama `etken_kod='ROTA'` (backfill atladı) → **EXISTS başarısız → 16de0128 iptal EDİLMEZ.**

➡️ Migration, **hedeflediği tam kaydı (küpe 184'ün fazla görevini) temizleyemez.** Tasarım §4.2 "Beklenti: 2 iptal" → **gerçekte 0.** Audit log da `iptal_edilen_count: 0` yazar.

**Düzeltme:** Backfill koşulunu `etken_kod IS NULL` yerine `(etken_kod IS NULL OR etken_kod='ROTA')` yap — ama **1. doz'a değmemeli**. `aciklama ILIKE '%2. doz%'` zaten `(1. doz)` kayıtlarını dışlar, dolayısıyla güvenli. Tamamlanmış/iptal kayıtlar partial index dışında (tamamlandi/iptal true) → index oluşturma çakışmaz. Bu düzeltmeyle cleanup'taki legit join çalışır.

### B3 — `tamamlandi=false` dedup eski koruma kaldırıyor (latent regresyon)

Canlı `gebelik_protokol_kontrol` 261 dedup:
```sql
WHERE NOT EXISTS (... aciklama='💉 ...(2. doz — düve)' AND iptal=false);  -- tamamlandi yok
```
→ Tamamlanmış (iptal=false) bir 2. doz kaydı **yeni üretimi bloklar** (doğru davranış: gebelik başına 1 kez).

Migration'ın yeni dedup'ı:
```sql
WHERE NOT EXISTS (... etken_kod='ROTA_2DOZ' AND iptal=false AND tamamlandi=false);  -- ← tamamlandi=false eklendi
```
→ Tamamlanmış kayıt artık bloklamıyor. 261+ penceresi doğuma kadar açık kaldığından, **2. doz tamamlandıktan sonraki her taramada yeni görev üretilir** (eğer aktif ROTA_2DOZ yoksa). B2 ile birleşince: tamamlanmış 2. doz'u `ROTA` etiketli olan + hâlâ Düve 261+ olan hayvan → **sürekli yeni sahte görev**.

Şu an canlıda tetikleyen hayvan **yok** (184 stray görevle korunuyor, 168 doğurmuş) — ama kırılgan ve mimari olarak yanlış. Ayrıca migration içinde **`ileri_gebe_gorev_kontrol` bu satırı içermiyor** (sadece `iptal=false`) → iki fonksiyon **tutarsız**.

**Düzeltme:** `gebelik_protokol_kontrol` dedup'ından `AND tamamlandi=false`'ı **çıkar** (eski semantik: non-cancelled herhangi bir ROTA_2DOZ varsa üretme). İki fonksiyon `etken_kod='ROTA_2DOZ' AND iptal=false` ile hizalansın. Partial index zaten sadece aktifleri kısıtladığından bu çelişmez.

---

## 3. Doğru Olan / Korunması Gerekenler

- ✅ **Yaklaşım doğru:** semantic key (`etken_kod`) + UNIQUE partial index, race-condition'ı DB seviyesinde kapatır. Geleceğe yönelik sağlam.
- ✅ **Partial index predicate** (`iptal=false AND tamamlandi=false`) audit trail'i bozmadan tek aktif kayıt garantisi veriyor.
- ✅ **`gebelik_protokol_kontrol` / `ileri_gebe_gorev_kontrol` gövdeleri** canlıyla birebir → rewrite güvenli, yan blok kaybı yok.
- ✅ **`islem_log` şeması uyumlu:** `id` (text, default var), `tip`, `snapshot` (jsonb) mevcut. Audit INSERT çalışır. (Not: `created_at` kolonu **yok** — tabloda `tarih timestamptz default now()`. Doğrulama sorgusu §4.2/5 `ORDER BY created_at` **patlar** → `tarih` kullan.)
- ✅ **`ON CONFLICT ... WHERE ... DO NOTHING`** partial index inference doğru yazılmış.

---

## 4. Önerilen Düzeltmeler (özet)

1. **B1:** `ileri_gebe_asi_tamamla` → `RETURNS jsonb`, `json_build_object`→`jsonb_build_object`, `v_vax_result jsonb`.
2. **B2:** Backfill koşulu → `AND (etken_kod IS NULL OR etken_kod = 'ROTA') AND aciklama ILIKE '%2. doz%'` (1. doz'a dokunmaz). Böylece tamamlanmış legit kayıtlar da `ROTA_2DOZ` olur, cleanup çalışır.
3. **B3:** `gebelik_protokol_kontrol` 261 dedup → `AND tamamlandi=false`'ı çıkar; `ileri_gebe_gorev_kontrol` ile hizala (`etken_kod='ROTA_2DOZ' AND iptal=false`).
4. **Doğrulama sorguları:** `ORDER BY created_at` → `ORDER BY tarih` (islem_log'da created_at yok).
5. **Ordering güvenliği (öneri):** Cleanup'ı (§6) **UNIQUE index (§2) ÖNCESİNE** al. Backfill B2 ile genişleyince, aynı hayvanda 2+ aktif ROTA_2DOZ oluşma ihtimali doğarsa index oluşturma abort eder. Önce dedupe → sonra index = güvenli sıra. (Şu an canlıda 2+ aktif yok ama savunma amaçlı.)
6. **Doğrulama beklentileri:** "2 iptal" → düzeltme sonrası **1** (sadece küpe 184 `16de0128`). 168 doğurmuş, aktif duplicate'i yok.

---

## 5. İş Mantığı / Work-Logic Uyumu

> Soru: "Var olan sistemi bozmadan iyileştiriyor mu? Work-logic ile ters düşen yeri var mı?"
> Kısa cevap: **Fonksiyonel olarak bozmuyor; iş değişmezi doğru.** 3 incelik var — 2'si zaten mevcuttu (regresyon değil), 1'i küçük kırılganlık (N3).

### 5.1 Protokol yolu ↔ Event-driven yol KASITLI TAMAMLAYICIDIR (kök borç DEĞİL)

⚠️ İlk taslakta "3 üretici / 2 zamanlama felsefesi = birleştirilmeli mimari borç" dedim — **bu yanlış çerçeve.** Doğrusu (kullanıcı notu):

- **Event-driven yol** (`ileri_gebe_asi_tamamla`, 1. doz+21): normal akış. Kullanıcı 1. doz'u yapınca rapel doğal olarak doğar.
- **Protokol/scheduler yolu** (`gebelik_protokol_kontrol` / `ileri_gebe_gorev_kontrol`, toh+261): **safety-net.** Maksat = unutulan/atlanan işi yakalamak (örn. 1. doz hiç yapılmadıysa ya da rapel bir şekilde oluşmadıysa, 261. günde yine de görev çıksın).

İkisi **redundancy değil, birbirinin sigortası.** Bu mimari **doğru ve korunmalı.** Asıl sorun hiçbir zaman "iki yol var" değildi — **iki yolun aynı işi farklı dedup anahtarıyla tanımlaması** idi (biri `aciklama='(2. doz)'`, diğeri `'(2. doz — düve)'`). String drift → backup, event-driven'in ürettiğini "görmedi" → duplicate.

➡️ **Bu fix tam da bunu çözüyor:** her iki yol artık ortak semantik anahtar `etken_kod='ROTA_2DOZ'` + UNIQUE index kullanıyor. Yani **safety-net, normal akışın işini artık doğru tanıyor ve tekrar üretmiyor.** Bu bir yama değil — tamamlayıcı tasarımın **çalışması için gereken hizalama.** Doğru iyileştirme.

**Kalan küçük caveat:** Scheduler önce ateşlerse (sayfa 261. günde açıldı, 1. doz henüz yeni tamamlandı), rapel `ON CONFLICT DO NOTHING` ile düşer → 2. doz'un `parent_id` linkajı (hangi 1. doz'a ait) o vakada kaybolabilir. İş açısından zararsız (tek 2. doz uygulanır); sadece izlenebilirlik (audit zinciri) bazen eksik kalır. Kabul edilebilir.

### 5.2 Listener (auto-close) mimarisinden kopma — regresyon DEĞİL (N1)

BUG-064 "iki kapı aynı yere varır": uygulama yapılınca `_gorev_dinle(hayvan, etken_kod)` eşleşen görevi kapatır. `_etken_kod_bul(Rota vaccine)` → `'ROTA'` döner. 2. doz `'ROTA_2DOZ'` olduğundan **genel aşı modalından** uygulanırsa listener onu kapatmaz.

- **Regresyon değil:** Canlıda scheduler 2. doz'ları zaten `etken_kod=NULL` idi → listener `'ROTA'`'yı NULL ile eşleştiremiyordu. Yeni kayıp yok.
- **Mimari kısıt:** Listener dose-aware olamaz (aşıyı görür, "kaçıncı doz" bilmez). Bu yüzden 2. doz **zaten** dose-aware tek yol olan butonla (`ileri_gebe_asi_tamamla`, ID ile kapatır) kapanmak zorunda. Fix bunu kötüleştirmiyor, kalıcılaştırıyor.

### 5.3 JS stok eşlemesi kırılganlığı (N3)

`js/ui.js:946` `_katTipMap`'te `'ROTA_2DOZ'` yok. 2. doz görevleri `stok_id` taşıdığı için `detayTamamla()` (ui.js:4037) `_etkenFiltrele`'ye gitmiyor → şu an patlamıyor. Ama Rota aşısının `stock_item_id`'si NULL olursa kullanıcı görevi kapatamaz. **Öneri:** `_katTipMap`'e `'ROTA_2DOZ': /rota|corona/i` ekle (2 satır, stok_id'ye bağımlılığı kaldırır).

### 5.4 Cross-pregnancy güvenliği — B3 sorunsuz

B3'te dedup'tan `tamamlandi=false` çıkardım → "tamamlanmış 2. doz bir sonraki gebeliği bloklar mı?" endişesi: **hayır.** Düve, 2. doz'u ilk gebelikte alır; doğunca İnek olur; 261-blok `grup ILIKE '%Düve%'` guard'ı bir daha tetiklenmez ("inekler tek doz"). Aynı gebelik içinde tamamlandıktan sonra tekrar üretimi de doğru biçimde bloklanır. ✓

### 5.5 Özet yargı

| Kriter | Değerlendirme |
|--------|---------------|
| İş değişmezi (hayvan başına ≤1 aktif 2. doz, atomik) | ✅ Doğru |
| Tamamlayıcı (event + safety-net) tasarımı koruyor mu? | ✅ Evet — ortak anahtarla artık **doğru** çalışıyor |
| Completion yolları bozuluyor mu? | ✅ Hayır (buton ID ile kapatır) |
| Cross-pregnancy | ✅ Güvenli (Düve guard) |
| Tarihî temizlik | ✅ Doğru (sadece aktif stray) |
| Listener kopması | ⚠️ Var ama regresyon değil (önceden NULL) |
| JS `_katTipMap` | ⚠️ N3 — sigorta için 2 satır eklenmeli |
| `parent_id` audit linkajı | ⚠️ Scheduler önce ateşlerse bazen kaybolur (kabul edilebilir) |

---

## 6. Açık Sorular (kullanıcıya)

1. **Migration'ı ben düzelteyim mi** (yukarıdaki 6 madde) yoksa sadece bu review yeterli mi?
2. Tamamlanmış 2. doz kayıtlarının `etken_kod`'unu `ROTA`→`ROTA_2DOZ` olarak **yeniden etiketlemek** uygun mu? (Mantıken doğru: 2. doz'un kendi semantik anahtarı olur. Geçmiş 1. doz `ROTA` kalır.) Bu B2 düzeltmesinin doğal sonucu.
3. `ileri_gebe_gorev_kontrol` hâlâ canlı scheduler — 3 yolun teke indirilmesi bu fix'in scope'u dışı (doğru karar). Onaylıyor musun, yoksa bu turda onu da kapatalım mı?
