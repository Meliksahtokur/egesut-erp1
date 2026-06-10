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

## ⚠️ Spec Revizyonu (2026-06-10 review sonrası)

**İlk yazılan spec'te 3 kritik hata vardı:**

1. **060a fix stratejisi yanlıştı** — Custom SQL bloğu öneriliyordu, ama `fn_dinle_uygulama` trigger'ı ZATEN `_gorev_dinle`'yi çağırıyor. Asıl sorun trigger'ın `IF NEW.etken_kod IS NOT NULL` koşulu.
2. **NULL etken_kod fallback'i tehlikeliydi** — Yanlış görevi kapatma riski (kalsiyum uygulaması oksitosin görevini kapatabilirdi)
3. **`v_class_name ILIKE '%Yağda Eriyen%'` çok geniş** — A, D, E, K vitaminlerinin hepsini E_VIT yapar

**Düzeltme sonrası gerçek kök neden:**
- Tek fix yeterli: **060b** — `_etken_kod_bul` düzeltilince `etken_kod` dolu kaydedilecek → trigger çalışacak → `_gorev_dinle` görevi kapatacak
- 060a için **ek kod değişikliği gerekmez** (trigger mimarisi zaten doğru)

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

## 3. Önerilen Çözüm (REVİZE)

### 3.1 Fix: `_etken_kod_bul` — E_VIT eşleşmesi

**Migration:** `supabase/migrations/20260610000001_bug060v2_etken_kod_vitamin.sql` (TEK DOSYA)

**Değişiklik:** Sadece E_VIT bloğu güncellenir, diğer etkenler aynen kalır.

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

**Neden bu sıra:**
1. `v_active_ing` en güvenilir — DB'de doğrudan "E Vitamini" yazıyor
2. `v_class_name` mevcut fallback — gelecekte başka marka eklenirse de yakalar
3. `v_stok_ad` — bilinen marka adları (yeldif), spesifik fallback

**Yapılmayacaklar (review feedback):**
- ❌ `v_class_name ILIKE '%Yağda Eriyen%'` — A/D/E/K hepsini yakalar, yanlış pozitif
- ❌ NULL etken_kod fallback'i — yanlış görevi kapatma riski
- ❌ `hizli_uygulama` RPC'ye custom SQL ekleme — trigger mimarisi zaten doğru

### 3.2 `hizli_uygulama` RPC'ye dokunulmayacak

**Neden:** Trigger mimarisi zaten doğru kurulmuş (`fn_dinle_uygulama` + `_gorev_dinle`). 060b fix uygulandığında:
1. `hizli_uygulama` → `uygulama_log` INSERT (etken_kod='E_VIT' artık dolu)
2. Trigger `fn_dinle_uygulama` → `IF NEW.etken_kod IS NOT NULL` → TRUE
3. `_gorev_dinle` çağrılır → `gorev_log` UPDATE → `tamamlandi=true`
4. UI "tamamlandı" gösterir

**Bu nedenle 060a için custom SQL bloğu gerekmez, sadece 060b fix yeterlidir.**

---

## 4. Uygulama Planı (SADE — 3 adım)

| # | Adım | Araç | Süre |
|---|------|------|------|
| 1 | Migration dosyasını yaz (`20260610000001_bug060v2_etken_kod_vitamin.sql`) | `write` (parçalı) | 3 dk |
| 2 | Ground truth'taki `_etken_kod_bul` (L9210) güncelle — atomik commit | `edit` + `git add` + `commit` | 2 dk |
| 3 | `supabase_migrate` ile SQL'i canlı DB'ye deploy et | MCP | 1 dk |
| 4 | Test: `_etken_kod_bul('99e2349b-...')` → 'E_VIT' doğrula | `supabase_rpc` | 1 dk |
| 5 | Test: 135 için yeni E vitamini uygulaması → `gorev_log.tamamlandi=true` | `supabase_query` | 3 dk |
| 6 | Test: Geri alma simetrisi (`hizli_uygulama_geri_al` çalışıyor mu) | `supabase_rpc` | 2 dk |
| 7 | Regression: `gorev_tamamla` hâlâ çalışıyor | `supabase_rpc` | 2 dk |
| 8 | Spec'i "ÇÖZÜLDÜ" işaretle, commit + push | `edit` + `shell` | 3 dk |

**Toplam tahmini süre:** ~20 dakika (önceki 30 dk'dan düştü — sadece 1 fix var)

### 4.1 Ground truth senkronizasyonu

Migration + ground truth aynı commit'te, atomik. Farklı commit'lerde olursa GitNexus tutarsızlık yakalar, sonraki geliştirici eski kodu görür.

---

## 5. Test Senaryoları (Sadeleştirilmiş)

### 5.1 Senaryo A: 135 numaralı hayvan, E vitamini (ana test)

**Önkoşul:** Migration deploy edilmiş, 135 için bekleyen E vitamini `gorev_log` kaydı var.

**Adımlar:**
1. UI'dan 135 numaralı hayvana git
2. "Protokol Uygula" butonuna bas
3. Stok olarak CAROFERTIN-E (`99e2349b-...`) seç
4. Doz: 20 ml, Rota: IM
5. "Kaydet" bas

**Beklenen sonuç:**
- `uygulama_log`'a yeni kayıt, `etken_kod='E_VIT'` (artık NULL değil)
- `stok_hareket`'e yeni kayıt
- **Trigger otomatik çalışır:** `_gorev_dinle` → `gorev_log` UPDATE → `tamamlandi=true`, `kapatan_ref='uygulama_log:<yeni_id>'`
- UI "tamamlandı" gösterir (hem görevler sekmesi hem detaylı geçmiş)
- `protokol_eksik_tara` artık 135 için E vitamini "eksik" göstermez

### 5.2 Senaryo B: Geri alma (simetri testi)

**Önkoşul:** Senaryo A başarıyla tamamlandı.

**Adımlar:**
1. 135'in detaylı geçmişinde yeni E vitamini uygulamasını bul
2. "Geri Al" butonuna bas
3. Onayla

**Beklenen sonuç:**
- `uygulama_log` kaydı silindi (veya iptal işaretlendi)
- `stok_hareket`'e ters kayıt (iade) eklendi
- `gorev_log`'daki görev tekrar `tamamlandi=false` yapıldı (mevcut `hizli_uygulama_geri_al` mantığı)
- UI "bekliyor" gösterir

### 5.3 Senaryo C: Regression — görevler sekmesinden tamamlama hâlâ çalışıyor mu?

**Adımlar:**
1. Yeni bir bekleyen görev oluştur (farklı hayvanda veya 135'te)
2. Görevler sekmesinden "Tamamlandı" işaretle

**Beklenen sonuç:**
- `gorev_log.tamamlandi=true`
- `stok_hareket` INSERT
- `islem_log` INSERT
- 060b değişikliği `gorev_tamamla`'yı etkilememeli

### 5.4 Senaryo D: NULL etken_kod edge case (review feedback testi)

**Senaryo:** `_etken_kod_bul` NULL dönen bir stok kullanılırsa görev kapatılmamalı.

**Adımlar:**
1. drug_product_id NULL olan bir stok seç (drug_classes eşleşmeyecek)
2. Bu stokla hizli_uygulama çağır

**Beklenen sonuç:**
- `uygulama_log.etken_kod` NULL kaydedilir
- Trigger `IF NEW.etken_kod IS NOT NULL` → FALSE → `_gorev_dinle` çağrılmaz
- `gorev_log.tamamlandi` DEĞİŞMEZ
- Stok yine düşer (bu kabul edilebilir — stok hareketi tetikleyici mantıktan bağımsız)

**Bu davranış kasıtlıdır:** NULL etken_kod'da yanlış görevi kapatma riski almaktansa, görevi açık bırakmak daha güvenli.

---

## 6. Kabul Kriterleri

- [ ] Migration dosyası `supabase/migrations/20260610000001_*.sql` yazıldı
- [ ] Ground truth'taki `_etken_kod_bul` L9210 güncellendi (aynı commit)
- [ ] `supabase_migrate` ile canlı DB'ye deploy edildi
- [ ] `_etken_kod_bul('99e2349b-...')` → 'E_VIT' dönüyor
- [ ] Senaryo A başarılı: 135 için `uygulama_log.etken_kod='E_VIT'` + `gorev_log.tamamlandi=true`
- [ ] Senaryo B başarılı: geri alma simetrisi çalışıyor
- [ ] Senaryo C başarılı: `gorev_tamamla` regression yok
- [ ] Senaryo D başarılı: NULL etken_kod'da görev kapatılmıyor
- [ ] Spec dosyası "ÇÖZÜLDÜ" işaretlendi
- [ ] Commit + push yapıldı
- [ ] `.claude/knowledge/bugs.md`'ye yeni ID ile (BUG-064+) eklendi (eski BUG-060 ile karışmaması için)

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

---

## 8. Gelecek İyileştirmeler (Spec Kapsamı Dışı)

1. **`gorev_log` oluşturulurken `etken_kod` her zaman set edilsin** — şu an NULL olarak oluşabiliyor, bu da 060b fix'in tam faydasını sınırlıyor (135'in tüm görevlerinde `etken_kod` NULL)
2. **Orphan `uygulama_log` kayıtları için temizlik scripti** — 135'teki 04:30 ve 04:50 kayıtları gibi etken_kod NULL olan kayıtlar raporlanmalı
3. **`_etken_dinle` fonksiyonu diğer vitaminler için de genişletilebilir** — D vitamini, A vitamini, K vitamini preparatları için
4. **Stok düşüşü + görev kapatma transaction'ı** — trigger PL/pgSQL içinde çalışıyor ama hata durumunda rollback davranışı test edilmeli

---

## 9. Referanslar

- `js/ui.js:1080-1102` — `_hayvanHizliUygulaKaydet` (handler)
- `js/ui.js:940-970` — `_protokolUygulaKaydet` (handler)
- `js/ui.js:3982` — görevler sekmesi `gorev_tamamla` çağrısı
- `supabase/migrations/99999999999999_ground_truth.sql:6556-6645` — `gorev_tamamla` RPC
- `supabase/migrations/...ground_truth.sql:9169-9224` — `_etken_kod_bul` RPC (060b fix yeri)
- `supabase/migrations/...ground_truth.sql:9224-9251` — `_gorev_dinle` (trigger tarafından çağrılır)
- `supabase/migrations/...ground_truth.sql:9256-9298` — `hizli_uygulama` RPC
- `supabase/migrations/...ground_truth.sql:9320-9355` — `hizli_uygulama_geri_al` (simetri)
- `supabase/migrations/...ground_truth.sql:9463-9470` — `fn_dinle_uygulama` trigger fonksiyonu
- `supabase/migrations/...ground_truth.sql:9472-9473` — `trg_dinle_uygulama` trigger tanımı
- `.claude/knowledge/bugs.md` — eski BUG-060 kaydı (UUID cast fix, e0f563d, farklı bug)

---

**Spec durumu:** 📋 Yazıldı, review sonrası revize edildi, uygulama bekliyor
