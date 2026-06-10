# BUG-060v2: Protokol Uygulama — Stok Düşüyor Ama Görev Tamamlanmıyor

**Tarih:** 2026-06-10
**Önem:** 🔴 Kritik (veri bütünlüğü + kullanıcı güveni)
**Durum:** 📋 Spec yazıldı, uygulama bekliyor
**Bildirim kaynağı:** Kullanıcı (canlı test, 2026-06-10)

**⚠️ İSİM ÇAKIŞMASI UYARISI:**
Eski BUG-060 (e0f563d, 2026-06-08) = "hizli_uygulama stok_hareket UUID type hatası" — zaten çözülmüş.
Bu bug **farklı** — kullanıcı aynı "60" numarasını kendi sayacıyla verdi, bizim sistemimizdeki BUG-060 ile ilgisi yok.
**Bu spec BUG-060v2 olarak adlandırıldı** — uygulama sonrası `.claude/knowledge/bugs.md`'ye yeni ID ile (BUG-064+) eklenecek.

**Kullanıcı bildirimi (aynen):**
> "60) 135 numaranın e vitamini görevi görevler sekmesinden tamamlanabildi ama protokol uygulama butonu ile tamamlanamadı, araştır. UI da tamamlanamadi göstermesine rağmen stoktan ürün çekmiş. bu bugu arastir."

**Anahtar gözlemler:**
- Aynı görev 2 farklı yoldan tamamlanabiliyor gibi görünüyor ama davranışları farklı
- Stok gerçekten düşmüş (yan etki: stok yanlış eksiye gidebilir, uygulamayı tekrar denerse çift düşer)
- UI tutarsızlığı → kullanıcı neye güveneceğini bilemez
- Eski BUG-060 (UUID cast) ile ilgisi yok — bu yeni bir bug

---

## ⚠️ Spec Revizyon Geçmişi

### Revizyon 1 (2026-06-10 review sonrası)
**İlk yazılan spec'te 3 kritik hata vardı:**

1. **060a fix stratejisi yanlıştı** — Custom SQL bloğu öneriliyordu, ama `fn_dinle_uygulama` trigger'ı ZATEN `_gorev_dinle`'yi çağırıyor. Asıl sorun trigger'ın `IF NEW.etken_kod IS NOT NULL` koşulu.
2. **NULL etken_kod fallback'i tehlikeliydi** — Yanlış görevi kapatma riski (kalsiyum uygulaması oksitosin görevini kapatabilirdi)
3. **`v_class_name ILIKE '%Yağda Eriyen%'` çok geniş** — A, D, E, K vitaminlerinin hepsini E_VIT yapar

**Düzeltme sonrası gerçek kök neden:**
- Tek fix yeterli: **060b** — `_etken_kod_bul` düzeltilince `etken_kod` dolu kaydedilecek → trigger çalışacak → `_gorev_dinle` görevi kapatacak
- 060a için **ek kod değişikliği gerekmez** (trigger mimarisi zaten doğru)

### Revizyon 2 (2026-06-10 kullanıcı feedback sonrası — Yaklaşım 2)
**Kullanıcı gözlemi:** "Hizli uygulama audit iz bırakmıyor, takip edilemiyor" + "İki kapı aynı yere varıyor, protokol bir nevi gorevler sisteminin backup i"

**Kullanıcı kararı:** **Yaklaşım 2** — Sadece 2 fix, JS handler'a dokunma.

**Neden JS'e "görev bul → redirect" eklenmemeli (yanlış mimari):**
- **Race condition:** İki call arasında başka kullanıcı aynı görevi tamamlarsa ne olur?
- **İş mantığı frontend'e kaçar:** DB seviyesinde garanti yok, bypass edilebilir
- **Trigger mimarisi zaten atomik:** `fn_dinle_uygulama` DB transaction içinde, JS'te taklit etmeye çalışmak gereksiz risk

**Final scope:**
- ✅ Fix #1: `_etken_kod_bul` E_VIT düzeltmesi (1 satır değişiklik)
- ✅ Fix #2: `hizli_uygulama` RPC'ye `islem_log` INSERT (audit trail)
- ✅ Bonus: `hizli_uygulama_geri_al` audit simetrisi (1 satır)
- ❌ JS handler değişikliği (YAPILMAYACAK)
- ❌ Unified RPC refactor (şimdilik YAPILMAYACAK)

**Tasarım felsefesi:** "İki kapı, aynı yer" — trigger mimarisini koru, sadece beslenecek veriyi düzelt + audit boşluğunu kapat. JS'i bu döngüye sokma.

---

## 1. Sorunun Doğrulanması (Kanıt)

### 1.1 Aynı hayvan (135), aynı stok, 2 farklı yol — 2 farklı sonuç

**135 numaralı hayvan** = `6a240106-d3b4-4d9f-940d-f06e13a99cca`
**Stok** = `99e2349b-4df7-4930-b79e-8172bc2e7dc0` (ürün adı: **CAROFERTIN-E**)

#### Yol A: Görevler sekmesi → `gorev_tamamla` RPC
- `js/ui.js:3982`: `await rpc('gorev_tamamla', { p_gorev_id, p_padok_hedef })`
- RPC (`ground_truth.sql:6556-6645`):
  1. `gorev_log.tamamlandi = true`, `tamamlanma_tarihi = now()` ✅
  2. `stok_hareket` INSERT (stok düşer) ✅
  3. `islem_log` INSERT (audit trail) ✅
- **Sonuç:** Hem görev tamamlanır hem stok düşer — UI doğru gösterir.

#### Yol B: Protokol uygulama → `hizli_uygulama` RPC
- `js/ui.js:1080-1102` (`_hayvanHizliUygulaKaydet`) ve `js/ui.js:940-970` (`_protokolUygulaKaydet`)
- İkisi de aynı RPC'yi çağırır: `rpc('hizli_uygulama', {...})`
- RPC (`ground_truth.sql:9256-9298`):
  1. `uygulama_log` INSERT
  2. **`fn_dinle_uygulama` trigger tetiklenir** (L9463-9470) — ama `IF NEW.etken_kod IS NOT NULL` koşulu var
  3. `stok_hareket` INSERT (stok düşer) ✅
  4. Stok kalan hesapla, return OK

### 1.2 DB'den alınan kanıt (2026-06-10)

`uygulama_log` tablosu (135 için son kayıtlar):

| created_at | hayvan_id | etken_kod | notlar |
|---|---|---|---|
| 2026-06-10 04:30:29 | 6a240106-... | **NULL** | "" |
| 2026-06-10 04:50:54 | 6a240106-... | **NULL** | "Görev tamamlama" |

`gorev_log` tablosu (135 için son 30 gün): Tüm kayıtlarda `etken_kod` NULL, hiçbir kayıt `tamamlandi=true` yapılmamış.

`drug_classes` tablosu (CAROFERTIN-E stok sınıfı):
- `class_name`: **"Yağda Eriyen Vitaminler"**
- `active_ingredient`: **"E Vitamini"**
- `group_name`: "Vitamin"

`_etken_kod_bul('99e2349b-...')` RPC çağrısı → **NULL** dönüyor (test edildi).

---

## 2. Kök Neden Analizi (REVİZE EDİLMİŞ)

### 2.1 Asıl kök neden: `_etken_kod_bul` "E Vitamini" class_name'ini tanımıyor

**Dosya:** `supabase/migrations/99999999999999_ground_truth.sql`
**Satır:** 9169-9224

**Mevcut kod (L9210):**
```sql
IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT';
```

**Sorun:** CAROFERTIN-E stoğunun `drug_classes.class_name` = **"Yağda Eriyen Vitaminler"** → `"%E Vit%"` substring'i **YOK** ("E"den sonra " " değil "riyen " geliyor).

**Doğru eşleşme sırası (en spesifikten genele):**
1. `v_active_ing ILIKE '%E Vitamini%'` — **en spesifik**, önce kontrol
2. `v_class_name ILIKE '%E Vit%'` — mevcut fallback (uyumluluk)
3. `v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%'` — bilinen marka adları

**❌ YAPILMAYACAK (review feedback):** `v_class_name ILIKE '%Yağda Eriyen%'` eklemek — A, D, E, K vitaminlerinin hepsini E_VIT yapar, gelecekte D vitamini preparatı girilince yanlış eşleşme olur.

### 2.2 Neden `hizli_uygulama` çalıştırdığında görev kapanmıyor (DÜZELTİLDİ)

**İlk yazılan spec'te hatalı varsayım:** "`hizli_uygulama` `gorev_log`'a hiç dokunmuyor"

**Gerçek mimari (ground truth'tan doğrulandı, L9463-9470):**
```sql
CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.etken_kod IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.hayvan_id, NEW.etken_kod, 'uygulama_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_uygulama ON public.uygulama_log;
CREATE TRIGGER trg_dinle_uygulama AFTER INSERT ON public.uygulama_log FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_uygulama();
```

**Akış:**
- `hizli_uygulama` → `uygulama_log` INSERT
- INSERT trigger `fn_dinle_uygulama`'yı çağırır
- Trigger `etken_kod` NULL değilse `_gorev_dinle` çağırır
- `_gorev_dinle` (L9224-9251) `gorev_log`'da eşleşen bekleyen görevi `tamamlandi=true` yapar

**Kırılma noktası:** `etken_kod` NULL kaydedildiği için trigger'ın koşulu FALSE → `_gorev_dinle` hiç çağrılmıyor.

**060b fix uygulandığında:** `etken_kod='E_VIT'` dolu kaydedilecek → trigger çalışacak → `_gorev_dinle` görevi kapatacak.

### 2.3 `_gorev_dinle` simetri kontrolü (doğrulandı)

`hizli_uygulama_geri_al` (ground truth L9320-9355) zaten `kapatan_ref` üzerinden görevi geri açıyor:
```sql
UPDATE public.gorev_log SET tamamlandi = false, tamamlanma_tarihi = NULL, kapatan_ref = NULL
WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;
```

**Simetri ✅ doğrulandı** — geri alma mevcut, ek değişiklik gerekmez.

### 2.4 Diğer etkenler için kontrol tablosu (referans)

| Etken | Mevcut kontrol | Yeterli mi? |
|---|---|---|
| OKSITOSIN | `v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%'` | ✅ |
| PG | `v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%'` | ✅ |
| **E_VIT** | `v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%'` | ❌ (eşleşmiyor) |
| ADEMIN | `v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%'` | ✅ |
| KALSIYUM | `v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%'` | ✅ |

---


## 3. Önerilen Çözüm (FİNAL — 2 fix, 1 migration)

**Tasarım felsefesi:** "İki kapı, aynı yer" — trigger mimarisi zaten doğru kurulmuş (`fn_dinle_uygulama` → `_gorev_dinle`). Bu mimariyi **bozmadan**, sadece **beslenecek veriyi düzelt** + **audit boşluğunu kapat**.

**Sistem mimarisi (korunacak):**
```
hizli_uygulama  ─┐
gorev_tamamla   ─┼─→ uygulama_log / gorev_log INSERT
                │
drug_admin      ─┤
vaccination     ─┘
                          ↓ (trigger)
                  fn_dinle_uygulama  →  _gorev_dinle  →  gorev_log UPDATE
```

Kim `uygulama_log`'a yazarsa yazsın (görevler sekmesi, hızlı uygulama, tedavi, gelecekte başka yol) **trigger otomatik** `gorev_log`'u kapatıyor. JS'i bu döngüye sokmak mimari temizliği bozar.

### 3.1 Fix #1: `_etken_kod_bul` — E_VIT eşleşmesi

**Dosya:** `supabase/migrations/99999999999999_ground_truth.sql` L9210
**Migration:** `supabase/migrations/20260610000001_bug064_etken_kod_vitamin_audit.sql` (TEK DOSYA, 2 fix birleşik)

**ESKİ (L9210):**
```sql
IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT';
```

**YENİ (active_ingredient öncelikli):**
```sql
IF v_active_ing ILIKE '%E Vitamini%'           -- en spesifik, önce kontrol
   OR v_class_name ILIKE '%E Vit%'              -- mevcut fallback (uyumluluk)
   OR v_stok_ad ILIKE '%yeldif%' 
   OR v_stok_ad ILIKE '%e vit%'
THEN RETURN 'E_VIT'; END IF;
```

**Sıralama gerekçesi:**
1. `v_active_ing` en güvenilir — DB'de doğrudan "E Vitamini" yazıyor
2. `v_class_name` mevcut fallback — gelecekte başka marka eklenirse de yakalar
3. `v_stok_ad` — bilinen marka adları (yeldif), spesifik fallback

**Yapılmayacak (review feedback):**
- ❌ `v_class_name ILIKE '%Yağda Eriyen%'` — A/D/E/K hepsini yakalar, yanlış pozitif

### 3.2 Fix #2: `hizli_uygulama` RPC'ye `islem_log` INSERT (audit trail)

**Dosya:** `supabase/migrations/99999999999999_ground_truth.sql` L9256-9298

**Sorun:** `gorev_tamamla` her durumda `islem_log` yazıyor, ama `hizli_uygulama` yazmıyor → hızlı uygulamalar audit trail'siz kalıyor → takip boşluğu.

**Çözüm:** `gorev_tamamla`'daki `islem_log` pattern'ini kopyala. RPC'de `uygulama_log` INSERT'inden sonra, `stok_hareket` INSERT'inden önce ekle.

**Eklenecek blok (yeni):**
```sql
-- Audit trail: hizli_uygulama da gorev_tamamla gibi islem_log yazmali
INSERT INTO public.islem_log (hayvan_id, islem_tipi, aciklama, referans_id)
VALUES (p_hayvan_id, 'HIZLI_UYGULAMA',
        COALESCE(v_stok.urun_adi, '?') || ' — ' || p_doz::text || ' ' || COALESCE(p_birim, ''),
        v_id);
```

**`islem_tipi` değeri:** `'HIZLI_UYGULAMA'` — `gorev_tamamla`'nın `'GOREV_TAMAMLA'` değeriyle simetrik.

**Neden `v_id` (uygulama_log.id) `referans_id` olarak:**
- `islem_log` tablosu `referans_id` kolonu zaten var (gorev_tamamla'da `gorev_log.id` kullanılıyor)
- `uygulama_log.id` ile bağ kurulur → audit'ten uygulamaya geri izleme yapılabilir

### 3.3 Yapılmayacaklar (net)

- ❌ **JS handler'a "görev bul → gorev_tamamla çağır" mantığı ekleme** — bu **yanlış mimari**:
  - Race condition: İki call arasında başka kullanıcı aynı görevi tamamlarsa ne olur?
  - İş mantığı frontend'e kaçar: DB seviyesinde garanti yok, bypass edilebilir
  - Trigger mimarisi zaten DB transaction içinde atomik — bunu JS'te taklit etmeye çalışmak gereksiz risk
- ❌ **Unified RPC refactor** — büyük refactor, ayrı oturum
- ❌ **`_etken_kod_bul` NULL fallback** — yanlış görev kapatma riski (kalsiyum uygulaması oksitosin görevini kapatabilirdi)

### 3.4 Akış (060b + 060c fix sonrası)

```
Kullanıcı: "Hizli uygulama" butonu → CAROFERTIN-E → Kaydet
                                              ↓
                        hizli_uygulama RPC
                                              ↓
            ┌─────────────────────────────────────────────┐
            │ 1. uygulama_log INSERT (etken_kod='E_VIT')   │  ← Fix #1 sonrası dolu
            │ 2. fn_dinle_uygulama TRIGGER                 │
            │    → IF NEW.etken_kod IS NOT NULL → TRUE     │
            │    → _gorev_dinle çağrılır                  │
            │    → gorev_log.tamamlandi=true               │
            │ 3. islem_log INSERT ('HIZLI_UYGULAMA')       │  ← Fix #2 (yeni)
            │ 4. stok_hareket INSERT (stok düşer)          │
            └─────────────────────────────────────────────┘
                                              ↓
              UI: "tamamlandı" + audit trail var + görev kapalı
```

---

## 4. Uygulama Planı (8 adım, ~20 dk)

| # | Adım | Araç | Süre |
|---|------|------|------|
| 1 | Migration dosyasını yaz (`20260610000001_bug064_etken_kod_vitamin_audit.sql`) — 2 fix birleşik | `write` (parçalı) | 3 dk |
| 2 | Ground truth'taki `_etken_kod_bul` L9210 güncelle | `edit` + git | 2 dk |
| 3 | Ground truth'taki `hizli_uygulama` RPC'ye `islem_log` INSERT ekle (stok_hareket'ten önce) | `edit` + git | 2 dk |
| 4 | Tek atomik commit (migration + ground truth) | `git add` + `commit` | 1 dk |
| 5 | `supabase_migrate` ile canlı DB'ye deploy et | MCP | 1 dk |
| 6 | Test A: `_etken_kod_bul('99e2349b-...')` → 'E_VIT' doğrula | `supabase_rpc` | 1 dk |
| 7 | Test B: 135 için yeni hizli uygulama → `uygulama_log.etken_kod='E_VIT'` + `gorev_log.tamamlandi=true` + `islem_log` kaydı | `supabase_query` | 3 dk |
| 8 | Test C: Geri alma simetrisi (`hizli_uygulama_geri_al` islem_log da geri almalı) | `supabase_rpc` | 2 dk |
| 9 | Test D: Regression — `gorev_tamamla` hâlâ çalışıyor | `supabase_rpc` | 2 dk |
| 10 | Test E: Edge case — C vitamini girilirse E_VIT görevi açık kalır (yanlış kapama yok) | UI / RPC | 2 dk |
| 11 | Spec'i "ÇÖZÜLDÜ" işaretle, commit + push | `edit` + `shell` | 1 dk |

**Toplam tahmini süre:** ~20 dakika (2 fix, 1 migration, 5 test)

### 4.1 Migration dosya yapısı (önerilen)

```sql
-- 20260610000001_bug064_etken_kod_vitamin_audit.sql
-- BUG-064 (eski BUG-060v2) — Protokol uygulama stok/gorev uyumsuzluk

-- Fix #1: _etken_kod_bul E_VIT düzeltmesi
CREATE OR REPLACE FUNCTION public._etken_kod_bul(...) ...
-- (yeni E_VIT bloğu: v_active_ing ILIKE '%E Vitamini%' öncelikli)

-- Fix #2: hizli_uygulama islem_log audit trail
CREATE OR REPLACE FUNCTION public.hizli_uygulama(...) ...
-- (uygulama_log INSERT'ten sonra, stok_hareket'ten önce islem_log INSERT)
```

### 4.2 Ground truth senkronizasyonu

Migration + ground truth **aynı commit'te**, atomik. Farklı commit'lerde olursa GitNexus tutarsızlık yakalar, sonraki geliştirici eski kodu görür.

### 4.3 `hizli_uygulama_geri_al` simetri sorunu

`hizli_uygulama_geri_al` (L9320-9355) audit log geri alma **yapmıyor**. Spec kapsamı: audit trail'in tutarlılığı için `islem_log` kaydı da geri alınmalı VEYA audit kaydında `referans_id` üzerinden ilişki kurulup geri alma durumunda "iptal" işaretlenmeli.

**Karar:** Spec kapsamında sadece ileri yönde audit ekle. Geri alma simetrisi **BUG-065** olarak ayrı bug'a bırakılabilir (scope kontrolü için). Veya bu PR'da `hizli_uygulama_geri_al`'a da `islem_log` ters kaydı eklenir (1 satır ek).

**Önerim:** Bu PR'da çöz — `hizli_uygulama_geri_al`'a `islem_log` INSERT ekle (`islem_tipi='HIZLI_UYGULAMA_GERI_AL'`, `referans_id=v_uygulama_id`). 2 satır ek, simetri tamamlanır.

---

## 5. Test Senaryoları (5 senaryo)

### 5.1 Senaryo A: 135 numaralı hayvan, E vitamini (ana test)

**Önkoşul:** Migration deploy edilmiş, 135 için bekleyen E vitamini `gorev_log` kaydı var.

**Adımlar:**
1. UI'dan 135 numaralı hayvana git
2. "Hızlı Uygulama" butonuna bas
3. Stok olarak CAROFERTIN-E (`99e2349b-...`) seç
4. Doz: 20 ml, Rota: IM
5. "Kaydet" bas

**Beklenen sonuç:**
- `uygulama_log`'a yeni kayıt, `etken_kod='E_VIT'` (artık NULL değil) ✅
- `fn_dinle_uygulama` trigger otomatik çalışır → `_gorev_dinle` → `gorev_log` UPDATE → `tamamlandi=true`, `kapatan_ref='uygulama_log:<yeni_id>'` ✅
- `islem_log`'a yeni kayıt, `islem_tipi='HIZLI_UYGULAMA'`, `referans_id=<uygulama_log_id>` ✅
- `stok_hareket`'e yeni kayıt ✅
- UI "tamamlandı" gösterir (hem görevler sekmesi hem detaylı geçmiş) ✅
- `protokol_eksik_tara` artık 135 için E vitamini "eksik" göstermez ✅

### 5.2 Senaryo B: Geri alma simetrisi (C ile aynı seferde test edilebilir)

**Önkoşul:** Senaryo A başarıyla tamamlandı.

**Adımlar:**
1. 135'in detaylı geçmişinde yeni E vitamini uygulamasını bul
2. "Geri Al" butonuna bas
3. Onayla

**Beklenen sonuç:**
- `uygulama_log` kaydı silindi (mevcut `hizli_uygulama_geri_al` semantiği)
- `stok_hareket`'e ters kayıt (iade) eklendi
- `gorev_log`'daki görev tekrar `tamamlandi=false` yapıldı (mevcut simetri)
- `islem_log`'a `'HIZLI_UYGULAMA_GERI_AL'` kaydı eklendi (yeni — Fix #2 simetrisi) ✅
- UI "bekliyor" gösterir

### 5.3 Senaryo C: Regression — görevler sekmesinden tamamlama hâlâ çalışıyor mu?

**Adımlar:**
1. Yeni bir bekleyen görev oluştur (farklı hayvanda veya 135'te)
2. Görevler sekmesinden "Tamamlandı" işaretle

**Beklenen sonuç:**
- `gorev_log.tamamlandi=true`
- `stok_hareket` INSERT
- `islem_log` INSERT (`'GOREV_TAMAMLA'` — mevcut davranış)
- 060b/060c değişiklikleri `gorev_tamamla`'yı etkilememeli

### 5.4 Senaryo D: NULL etken_kod edge case (güvenli fallback)

**Senaryo:** `_etken_kod_bul` NULL dönen bir stok kullanılırsa görev kapatılmamalı.

**Adımlar:**
1. drug_product_id NULL olan bir stok seç (drug_classes eşleşmeyecek)
2. Bu stokla hizli uygulama çağır

**Beklenen sonuç:**
- `uygulama_log.etken_kod` NULL kaydedilir
- Trigger `IF NEW.etken_kod IS NOT NULL` → FALSE → `_gorev_dinle` çağrılmaz
- `gorev_log.tamamlandi` DEĞİŞMEZ ✅
- `islem_log` yine de yazılır (audit trail var — kimin ne yaptığı belli) ✅
- Stok yine düşer (bu kabul edilebilir — stok hareketi tetikleyici mantıktan bağımsız)

**Bu davranış kasıtlıdır:** NULL etken_kod'da yanlış görevi kapatma riski almaktansa, görevi açık bırakmak daha güvenli. Ama audit trail her halukarda yazılır → "kim ne zaman bu stoğu kullandı?" takibi yapılabilir.

### 5.5 Senaryo E: Yanlış eşleşme edge case (C vitamini girişi, E_VIT görevi beklerken)

**Senaryo:** Protokol E vitamini bekliyor, kullanıcı hızlı uygulama ile C vitamini girerse ne olacak?

**Adımlar:**
1. 135'te E_VIT görevi `tamamlandi=false`, `etken_kod='E_VIT'` olarak mevcut
2. C vitamini stoğu seç (etken_kod='C_VIT' veya NULL)
3. Kaydet

**Beklenen sonuç:**
- `uygulama_log.etken_kod` 'C_VIT' veya NULL olur
- `fn_dinle_uygulama` → `_gorev_dinle(135, 'C_VIT', ...)` çağrılır
- `_gorev_dinle` SELECT: `WHERE hayvan_id=135 AND etken_kod='C_VIT' AND tamamlandi=false` → E_VIT görevi `etken_kod='E_VIT'` olduğu için **EŞLEŞMEZ** ✅
- E_VIT görevi `tamamlandi=false` kalır ✅
- `islem_log` yazılır (C vitamini uygulandı kaydı) ✅
- C vitamini stoğu düşer ✅
- `protokol_eksik_tara` E_VIT görevini hâlâ "eksik" gösterir (doğru davranış) ✅

**Bu testin önemi:** Yanlış eşleşme YOK — trigger sadece `etken_kod` eşleşmesine bakar, tarih/akıllı tahmin yok. **Güvenli davranış.**

---

## 6. Kabul Kriterleri

- [ ] Migration dosyası `supabase/migrations/20260610000001_bug064_etken_kod_vitamin_audit.sql` yazıldı
- [ ] Ground truth'taki `_etken_kod_bul` L9210 güncellendi (aynı commit)
- [ ] Ground truth'taki `hizli_uygulama` RPC'ye `islem_log` INSERT eklendi (aynı commit)
- [ ] Ground truth'taki `hizli_uygulama_geri_al` RPC'ye `'HIZLI_UYGULAMA_GERI_AL'` audit simetrisi eklendi (aynı commit, opsiyonel ama önerilir)
- [ ] `supabase_migrate` ile canlı DB'ye deploy edildi
- [ ] `_etken_kod_bul('99e2349b-...')` → `'E_VIT'` dönüyor
- [ ] Senaryo A başarılı: 135 için `uygulama_log.etken_kod='E_VIT'` + `gorev_log.tamamlandi=true` + `islem_log` kaydı var
- [ ] Senaryo B başarılı: geri alma simetrisi çalışıyor (islem_log da geri alınıyor)
- [ ] Senaryo C başarılı: `gorev_tamamla` regression yok
- [ ] Senaryo D başarılı: NULL etken_kod'da görev kapatılmıyor (audit hâlâ yazılıyor)
- [ ] Senaryo E başarılı: C vitamini girilince E_VIT görevi açık kalıyor (yanlış kapama yok)
- [ ] Spec dosyası "ÇÖZÜLDÜ" işaretlendi
- [ ] Commit + push yapıldı
- [ ] `.claude/knowledge/bugs.md`'ye BUG-064 entry'si (zaten eklendi) "çözüldü" işaretlendi

---

## 7. Riskler ve Önlemler

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Migration hatası → canlı DB bozulur | Düşük | Yüksek | `supabase_migrate` öncesi SQL syntax kontrolü |
| `v_active_ing ILIKE '%E Vitamini%'` çok spesifik, başka markayı yakalamaz | Çok düşük | Düşük | `v_class_name` ve `v_stok_ad` fallback'leri korundu |
| `gorev_tamamla` artık çalışmıyor (regression) | Çok düşük | Orta | Senaryo C testi zorunlu, `_etken_kod_bul` değişikliği `gorev_tamamla` path'ini etkilemez |
| 135 için geçmiş orphan kayıtlar (etken_kod NULL) | Kesin | Düşük | Yeni uygulama bunları etkilemez, orphan kalır — ayrı temizlik task'ı |
| D vitamini preparatı girilirse yanlış eşleşme | Düşük | Orta | `v_class_name ILIKE '%Yağda Eriyen%` EKLENMEDİ (review feedback) |
| NULL etken_kod'da görev kapatılmıyor (yanlış görev kapatma riski alınmadı) | Kesin | Düşük | Kasıtlı — Senaryo D testi, güvenli tarafta kalmak |
| `hizli_uygulama_geri_al` audit simetrisi unutulursa log tutarsızlığı | Orta | Düşük | Bu PR'da 1 satır ekle (`islem_tipi='HIZLI_UYGULAMA_GERI_AL'`) |
| JS tarafında race condition (kullanıcı çift tıklama) | Düşük | Düşük | `_gorev_dinle` `ORDER BY hedef_tarih LIMIT 1` ile atomik, çift tetikleme görevi tekrar kapatmaya çalışır ama `tamamlandi=true` zaten |

---

## 8. Gelecek İyileştirmeler (Spec Kapsamı Dışı)

1. **`gorev_log` oluşturulurken `etken_kod` her zaman set edilsin** — şu an NULL olarak oluşabiliyor, bu da fix'in tam faydasını sınırlıyor (135'in tüm görevlerinde `etken_kod` NULL)
2. **Orphan `uygulama_log` kayıtları için temizlik scripti** — 135'teki 04:30 ve 04:50 kayıtları gibi etken_kod NULL olan kayıtlar raporlanmalı
3. **`_etken_kod_bul` fonksiyonu diğer vitaminler için de genişletilebilir** — D vitamini, A vitamini, K vitamini preparatları için
4. **Tüm uygulama kapıları (hizli, drug_admin, vaccination) için audit trail standardizasyonu** — `islem_tipi` enum'u + UI'da audit log görüntüleme
5. **"İki kapı, aynı yer" görselleştirmesi** — UI'da hangi uygulama hangi trigger'dan geçti, hangi görevi neden kapattı — debug için

---

## 9. Referanslar

- `js/ui.js:1080-1102` — `_hayvanHizliUygulaKaydet` (handler)
- `js/ui.js:940-970` — `_protokolUygulaKaydet` (handler)
- `js/ui.js:3982` — görevler sekmesi `gorev_tamamla` çağrısı
- `supabase/migrations/99999999999999_ground_truth.sql:6556-6645` — `gorev_tamamla` RPC
- `supabase/migrations/...ground_truth.sql:9169-9224` — `_etken_kod_bul` RPC (**Fix #1 yeri**)
- `supabase/migrations/...ground_truth.sql:9224-9251` — `_gorev_dinle` (trigger tarafından çağrılır)
- `supabase/migrations/...ground_truth.sql:9256-9298` — `hizli_uygulama` RPC (**Fix #2 yeri**)
- `supabase/migrations/...ground_truth.sql:9320-9355` — `hizli_uygulama_geri_al` (simetri, Fix #2 audit geri alma)
- `supabase/migrations/...ground_truth.sql:9463-9473` — `fn_dinle_uygulama` trigger fonksiyonu
- `supabase/migrations/...ground_truth.sql:9472-9473` — `trg_dinle_uygulama` trigger tanımı
- `.claude/knowledge/bugs.md` — BUG-064 entry (zaten eklendi) + eski BUG-060 (UUID cast, farklı bug, e0f563d)

---

**Spec durumu:** 📋 Final revize (Yaklaşım 2 — 2 fix, 1 migration), uygulama bekliyor

**Tasarım felsefesi özeti:** "İki kapı, aynı yer" — trigger mimarisini koru, sadece beslenecek veriyi düzelt + audit boşluğunu kapat. JS'i bu döngüye sokma.
