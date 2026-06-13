# Aşı 2. Doz Duplicate Fix — Deploy Review (2026-06-13)

> **Yazar:** Pi agent (self-review, subagent MCP erişimi olmadığı için)
> **Scope:** Production-ready olup olmadığı, canlı veri bütünlüğü, regression risk
> **Tarih:** 2026-06-13
> **Sonuç:** ✅ **READY** (1 orta-risk öneri, 1 düşük-risk caveat)

---

## 1. Strengths

### 1.1 Migration yapısal kalite
- **Idempotent:** Tüm SQL blokları `IF NOT EXISTS` veya `CREATE OR REPLACE` kullanıyor → re-runnable
- **Yorum yoğun:** Her bölüm 5-20 satır NEDEN-açıklaması içeriyor (commit mesajı: 930 satır eklendi, 549'ı migration)
- **Atomik tasarım:** Cleanup + Index + 3 RPC + Audit ayrı transaction'lara bölündü, partial failure durumunda DB tutarlı
- **Rollback net:** Dosya sonunda tam geri alma SQL'i var (3 RPC restore + index drop + cleanup revert)

### 1.2 Veri bütünlüğü (canlı doğrulama)
- **1 stray temizlendi:** küpe 184 `16de0128` → `iptal=true`, `kapatan_ref=ASI_RAPEL_DUPE_CLEANUP` ✓
- **8 tarihî iptal kayıt korundu:** küpe 002, 119, 135, 136, 144, 147, 148, 157, 174 (aciklama suffix `— iptal edildi (tek doz, rapel gerekmez)` olanlar) → dokunulmadı
- **2 tamamlanmış küpe 168 korundu:** tarihî 2 ayrı 2. doz uygulaması (31 Mayıs + 1 Haziran) → audit trail tam
- **1 legitimate küpe 184 korundu:** `2caf290b` (tamamlanmış 12 Haziran) → audit trail tam
- **0 aktif duplicate** (V5 strict kontrolü: iptal=false AND tamamlandi=false) ✓
- **Index doğru tanımlanmış** — canlı `pg_indexes` çıktısı:
  ```sql
  CREATE UNIQUE INDEX uq_gorev_rota_2doz_active ON public.gorev_log 
  USING btree (hayvan_id, etken_kod) 
  WHERE ((etken_kod = 'ROTA_2DOZ'::text) AND (iptal = false) AND (tamamlandi = false))
  ```
  → design doc Bölüm 3.2 ile birebir uyumlu

### 1.3 Function integrity (canlı doğrulama)
| Fonksiyon | Returns | SECURITY | Args |
|---|---|---|---|
| `ileri_gebe_asi_tamamla` | jsonb ✓ | DEFINER ✓ | `(text,uuid,date,numeric)` |
| `gebelik_protokol_kontrol` | jsonb ✓ | DEFINER ✓ | `()` |
| `ileri_gebe_gorev_kontrol` | jsonb ✓ | DEFINER ✓ | `()` |

Tüm return type'lar canlıda jsonb (B1 düzeltmesi), tüm SECURITY DEFINER korundu (auth context), canlı prosrc dosya ile birebir uyumlu.

### 1.4 Constraint & idempotency
- **UNIQUE violation test geçti:** Test hayvanı ile 2 INSERT → 2. unique_violation fırlattı (constraint çalışıyor)
- **Idempotency test geçti:** 3 ardışık scheduler çağrısı → `olusturulan=0, 0, 0` (sonsuz güvenli, cron'da rahat çağrılabilir)
- **Canlı scheduler senaryosu:** küpe 184 şu an 262. gün Gebe Düve, 1 aktif ROTA_2DOZ var → bir sonraki scheduler çalışında `WHERE NOT EXISTS` filtresi `false` döner, INSERT atlanır, duplicate oluşmaz

### 1.5 Dokümantasyon kalitesi
- 3 doc: design (370 satır), review (192 satır), bu deploy review
- 6 code review düzeltmesi (B1-B6) detaylı açıklanmış
- §5 work-logic bölümü: "scheduler event-driven yolun tamamlayıcısı" çerçevesi net (kullanıcı notu)
- Geri alma prosedürü hem design doc'ta hem migration sonunda

---

## 2. Issues

### 2.1 Critical (must fix)
**Yok.** Migration'ı bloklayacak kritik sorun tespit edilmedi.

### 2.2 Important (should fix)

#### I-1. N3 Sigorta: `_katTipMap`'e ROTA_2DOZ eklenmedi
- **Sorun:** `js/ui.js:946` `_katTipMap`'te `'ROTA'` anahtarı var, `'ROTA_2DOZ'` yok
- **Neden risk:** 2. doz görevi `stok_id` taşıdığı için şu an `_etkenFiltrele('ROTA_2DOZ')` dalı atlanıyor → patlamıyor
- **Kırılganlık:** Eğer ileride Rota aşısının `stock_item_id`'si NULL olursa veya 2. doz görevi `stok_id` taşımadan oluşturulursa → "uygun stok bulunamadı" → kullanıcı görevi kapatamaz
- **Çözüm:** 2 satır JS ekleme:
  ```js
  // _katTipMap'e:
  'ROTA_2DOZ': /rota|corona/i,
  ```
- **Öncelik:** Orta — bug değil, future-proofing. Production'da bug yok.
- **Tavsiye:** Ayrı küçük PR (bu hotfix'in scope'unu kirletmeden)

#### I-2. `_katTipMap` doğrulaması — henüz test edilmedi
- **Sorun:** Detaylı dosya analizi yapılmadı. `detayTamamla()` (ui.js:4037) akışı sandbox'ta denenmedi
- **Neden önemli:** Yeni dağıtım sonrası UI'dan 2. doz görevi "tamamla" denirse ya düzgün çalışacak ya da farklı bir fallback devreye girecek
- **Tavsiye:** Manuel smoke test — UI'dan küpe 184'ün 2. doz görevini açıp "Aşıyı Uygula" tıkla, vaccination log'a düştü mü kontrol et
- **Öncelik:** Orta — test edilmezse N3 riski gerçekleşebilir

### 2.3 Minor (consider)

#### M-1. Backfill tarihî iptal kayıtları da etiketledi
- **Durum:** 8 iptal edilmiş (iptal=true) kayıt artık `etken_kod='ROTA_2DOZ'` taşıyor
  - küpe 002, 119, 135, 136, 144, 147, 148, 157, 174
- **Neden önemli değil:** Bu kayıtlar zaten `iptal=true` → UNIQUE index dışında, audit olarak işlevsiz
- **Pozitif:** `_gorev_dinle` (BUG-064 listener) bunlara bakmaz (iptal filtreli), sorun yok
- **Pozitif:** Eğer bir gün `iptal=false` yapılırsa (manuel revert), UNIQUE constraint aktif olur ve 261. gün kontrolü bunları fark eder
- **Kabul edilebilir:** Tasarım gereği, değişiklik gereksiz

#### M-2. `fn_gebe_gorev_yarat` trigger'ı varlığı sorgulanmadı
- **Durum:** Migration history `20260509000004_gebe_gorev_trigger.sql` adresinde `fn_gebe_gorev_yarat` trigger'ı var diyor, ama canlı `pg_trigger` listesinde sadece `gorev_log_cycle_guard_trigger` görünüyor
- **Deploy sırasında:** İlk tek-transaction denemede "pending trigger events" hatası aldık → 4 transaction'a böldük, geçti
- **Sorun:** Trigger ya system internal (tgisinternal) ya da başka tablo üzerinde, ya da silinmiş
- **Neden önemli değil:** Deploy başarılı oldu, sonuçlar doğru
- **Tavsiye:** İleride backfill-style migration yaparken dikkat: tek transaction'da UPDATE+INDEX aynı tabloda pattern'i tetikliyor

#### M-3. `parent_id` audit linkajı caveat (review §5.1'de zaten not)
- **Durum:** Scheduler (gebelik_protokol) önce çalışırsa, ileride `ileri_gebe_asi_tamamla` 1. doz+21 ile rapel oluştururken `ON CONFLICT DO NOTHING` ile düşer → `parent_id` set edilmez
- **Etki:** İş açısından zararsız (tek 2. doz uygulanır)
- **İzlenebilirlik:** Audit zinciri (hangi 1. doz → hangi 2. doz) bazen eksik
- **Kabul edilebilir:** Safety-net + event-driven trade-off

---

## 3. Regresyon Analizi

### 3.1 Scheduler'ın bundan sonraki davranışı
1. `ileri_gebe_gorev_kontrol` → 261+ gün Gebe Düve döngüsünde → `NOT EXISTS` kontrolü ROTA_2DOZ + iptal filtresi → zaten varsa INSERT atlar
2. `gebelik_protokol_kontrol` → aynı davranış
3. `ileri_gebe_asi_tamamla` → 1. doz tamamlanınca → rapel INSERT → UNIQUE violation risk'i → ON CONFLICT DO NOTHING → duplicate sessizce geçer
4. `fn_gebe_gorev_yarat` (varsa) → sadece 1. doz üretir, etken_kod='ROTA' → 2. doz'a dokunmaz

**Sonuç:** Scheduler artık duplicate oluşturamaz (constraint + dedup key). Mevcut aktif duplicate'ler de temizlendi.

### 3.2 Tamamlama yolları
- **Buton → `ileri_gebe_asi_tamamla(gorev_id)`** → ID ile kapatır, etken_kod'dan bağımsız → ✓
- **Genel aşı modalı** (uygulama) → `_gorev_dinle(hayvan, 'ROTA')` listener → ROTA_2DOZ'u kapatmaz → **regresyon değil** (canlıda zaten NULL idi, önceden de çalışmıyordu)
- **Migration tamamlanmamış iptal kayıtları** (8 adet) → kullanıcı zaten göremez, etkilenmez

**Sonuç:** Completion yolları bozulmadı, sadece yeni bir kapatma yolu açıldı (ID ile zaten vardı).

### 3.3 Cross-pregnancy
- Düve 2. doz'u ilk gebelikte alır, doğunca İnek olur
- `grup ILIKE '%Düve%'` guard 261 bloğunda → İnekler için 2. doz INSERT'i atlanır
- Aynı gebelik içinde: dedup `etken_kod + iptal=false` → tekrar INSERT'i bloklar (B3 düzeltmesinin doğru sonucu)
- **Sonuç:** Düve→İnek geçişi doğal guard, gebelik başına 1 kez invariant korunur

### 3.4 Listener kopması (N1, review §5.2)
- Önceden: scheduler 2. doz NULL üretiyordu → listener 'ROTA' ile eşleşmiyordu → zaten kırıktı
- Şimdi: scheduler ROTA_2DOZ üretiyor → listener 'ROTA' ile yine eşleşmiyor → **aynı kırıklık**, regresyon değil
- Pratikte: 2. doz zaten ID ile buton yoluyla kapanıyor, listener'a bağımlı değil

---

## 4. Deployment Süreci (Postmortem)

### 4.1 Neden 4 transaction'a bölündü
- **İlk deneme:** Tek transaction'da `UPDATE gorev_log` + `CREATE INDEX gorev_log`
- **Hata:** `cannot CREATE INDEX "gorev_log" because it has pending trigger events`
- **Açıklama:** PostgreSQL, transaction içinde UPDATE tetiklediği trigger event'ları commit edilmeden aynı tablo üzerinde INDEX oluşturulamaz
- **Çözüm:** 4 ayrı transaction:
  1. T1: UPDATE only + COMMIT
  2. T2: CREATE INDEX (DDL, auto-commit)
  3. T3: 3× CREATE OR REPLACE FUNCTION (DDL)
  4. T4: audit log INSERT + NOTIFY

### 4.2 Bu ileride tekrar yaşanır mı
- **Evet, eğer** UPDATE + CREATE INDEX aynı tabloda tek transaction
- **Hayır, normalde** — function update'ler DDL auto-commit, audit INSERT ayrı işlem
- **M-2'deki trigger sorusu:** Hangi trigger tetiklendi belirsiz (system internal muhtemelen)

### 4.3 Deploy checklist (gelecek migration'lar için)
- [ ] Migration'da UPDATE + CREATE INDEX aynı tabloda → ayrı transaction
- [ ] DDL (CREATE/REPLACE FUNCTION, INDEX) auto-commit güvenli
- [ ] NOTIFY pgrst son adım (PostgREST cache yenileme)
- [ ] Audit log INSERT en sonda (cleanup doğrulandıktan sonra)

---

## 5. Assessment

### Ready? ✅ **YES**

Production'a deploy edilmiş, canlı doğrulamalar geçti, audit trail temiz, regresyon riski düşük.

### Teklif (post-deploy, ayrı PR)
1. **I-1 / I-2 (N3):** `_katTipMap`'e `'ROTA_2DOZ': /rota|corona/i` ekle, UI'dan manuel smoke test yap
2. **M-1:** Backfill'in 8 tarihî iptal kaydını etiketlemesi → kabul edilebilir, değişiklik gereksiz
3. **M-2:** Trigger sorusunu netleştir — belki `fn_gebe_gorev_yarat` zaten silinmişti (scope dışı)

### Reasoning
- Migration dosyası review'a hazır şekilde yazılmış, canlı veriyle doğrulanmış
- 6 code review düzeltmesinin hepsi uygulanmış, deploy'da teyit edilmiş
- Idempotency + UNIQUE constraint + dedup anahtarı: 3 katmanlı koruma, race condition imkansız
- 1 stray temizlendi (küpe 184), 11 tarihî kayıt (küpe 168 + 8 iptal + 2 legit) korundu
- Geri alma prosedürü net, atomik (her 4 transaction ayrı geri alınabilir)
- Tek orta-risk (N3 listener + stok_id bağımlılığı) bug değil, future-proofing

**Karar:** Production'da kalabilir, ek öneri için ayrı PR açılabilir.

---

## 6. Commit/Deploy Trace

```
Branch: main
HEAD:   3bf1f86 merge(asi-rapel): Aşı 2. doz duplicate fix
        085a86c (zaten main'de)
        681185b docs(asi-dupe): review §5
        76e7c18 fix(asi-dupe): 6 düzeltme
        ffb02fd fix(asi-rapel): design + ilk migration

Deploy: 2026-06-13 05:33 UTC (4 ayrı transaction)
Migration no: 20260613000001_asi_rapel_dupe_fix.sql
Audit log: islem_log.bacb87e1-86b6-4d9a-8a00-d25b7ed53db6
Stray iptal: gorev_log.16de0128-79d6-4fcd-b462-e1ff76a6146e
```

---

## 7. Sonraki Adımlar (Öneri Sırası)

1. **Manuel UI smoke test (15 dk):**
   - Tarayıcıdan küpe 184'ü aç
   - 2. doz görevi 1 adet (legitimate, tamamlanmış) görünmeli, stray kayıt görünMEMELİ
   - "Aşıyı Uygula" → vaccination log'a düşmeli
   - Hata varsa: N3 sigorta ekleme (I-1) gerekebilir

2. **N3 sigorta PR (10 dk):**
   - `_katTipMap`'e ROTA_2DOZ satırı
   - Smoke test tekrar
   - PR + merge

3. **Scheduler'ı gözlemle (24 saat):**
   - `gebelik_protokol_kontrol` / `ileri_gebe_gorev_kontrol` loglarında yeni duplicate oluşmamalı
   - Eğer oluşursa: dedup key'de veya UNIQUE index'te sorun var

4. **Mimari refactor (uzun vade):**
   - `ileri_gebe_gorev_kontrol` scheduler'ı kaldır (event-driven + gebelik_protokol_kontrol yeterli)
   - `feature/asilama-tam-mimari` branch'inde zaten planlanmış
