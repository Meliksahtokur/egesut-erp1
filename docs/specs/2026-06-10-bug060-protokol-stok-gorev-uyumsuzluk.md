# BUG-060: Protokol Uygulama — Stok Düşüyor Ama Görev Tamamlanmıyor

**Tarih:** 2026-06-10
**Önem:** 🔴 Kritik (veri bütünlüğü + kullanıcı güveni)
**Durum:** 📋 Spec yazıldı, uygulama bekliyor
**Bildirim kaynağı:** Kullanıcı (canlı test)

**Kullanıcı bildirimi (aynen):**
> "60) 135 numaranın e vitamini görevi görevler sekmesinden tamamlanabildi ama protokol uygulama butonu ile tamamlanamadı, araştır. UI da tamamlanamadi göstermesine rağmen stoktan ürün çekmiş. bu bugu arastir."

**Anahtar gözlemler:**
- Aynı görev 2 farklı yoldan tamamlanabiliyor gibi görünüyor ama davranışları farklı
- Stok gerçekten düşmüş (yan etki: stok yanlış eksiye gidebilir, uygulamayı tekrar denerse çift düşer)
- UI tutarsızlığı → kullanıcı neye güveneceğini bilemez

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
  1. `uygulama_log` INSERT (etken_kod NULL olarak!) ⚠️
  2. `stok_hareket` INSERT (stok düşer) ✅
  3. Stok kalan hesapla, return OK
  4. **`gorev_log`'a DOKUNMUYOR** ❌
- **Sonuç:** Stok düşer ama görev tamamlanmaz — UI "tamamlanmadı" gösterir.

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

## 2. Kök Neden Analizi

İki ayrı bug birlikte aynı semptomu üretiyor:

### 2.1 BUG-060a: `hizli_uygulama` RPC `gorev_log`'u güncellemiyor

**Dosya:** `supabase/migrations/99999999999999_ground_truth.sql`
**Satır:** 9256-9298

**Mevcut kod (özet):**
```sql
INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

-- Stok düşüm
INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz, ...);
```

**Eksik olan:** `gorev_log` tablosunda eşleşen bekleyen görevin `tamamlandi=true` yapılmaması.

**Neden tehlikeli:**
- Stok düşer → stok sayımı yanlış olur
- Aynı uygulamayı tekrar denerse çift stok düşer
- `protokol_eksik_tara` fonksiyonu (L9326 fallback) uygulama_log'a yazılan kaydı geçici olarak "tamamlandı" sayıyor — bu da ek bir tutarsızlık yaratıyor

**Doğru davranış:** `hizli_uygulama` çağrıldığında:
1. `uygulama_log` INSERT
2. `stok_hareket` INSERT
3. **`gorev_log` UPDATE** — eşleşen bekleyen görevi atomik olarak kapat
4. Tek `islem_log` snapshot'ı oluştur (audit)

### 2.2 BUG-060b: `_etken_kod_bul` "E Vitamini" class_name'ini tanımıyor

**Dosya:** `supabase/migrations/99999999999999_ground_truth.sql`
**Satır:** 9169-9224

**Mevcut kod (özet):**
```sql
IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT';
```

**Sorun:** CAROFERTIN-E stoğunun `drug_classes.class_name` = **"Yağda Eriyen Vitaminler"** → `"%E Vit%"` substring'i **YOK** ("E"den sonra " " değil "riyen " geliyor).

**Doğru eşleşme için:**
- `v_class_name` "Yağda Eriyen" içeriyor (vitamin olduğu anlaşılıyor)
- `v_active_ing` "E Vitamini" içeriyor
- Fallback: `v_class_name` "vitamin" kelimesini içeriyor (gelecek yeni vitamin preparatları için)

**Simetri notu — diğer etkenler için kontrol tablosu:**

| Etken | Mevcut kontrol | Yeterli mi? |
|---|---|---|
| OKSITOSIN | `v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%'` | ✅ |
| PG | `v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%'` | ✅ |
| **E_VIT** | `v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%'` | ❌ |
| ADEMIN | `v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%'` | ✅ (sadece ademin için) |
| KALSIYUM | `v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%'` | ✅ |

### 2.3 Semptom neden iki bug'ın bileşimi?

- **060a olmasaydı:** Sadece yanlış class eşleşmesi olurdu, görev `gorev_tamamla` ile yine tamamlanırdı.
- **060b olmasaydı:** 060a fix uygulansa bile `protokol_eksik_tara` SQL'inde `g.etken_kod = v_rec.ek` sorgusu boşa çıkardı — scanner "E vitamini eksik" göstermeye devam ederdi.

**İkisi birlikte tam senaryo:**
1. Kullanıcı 135 için "E vitamini" görevi oluşturur → `gorev_log` kaydı oluşur (etken_kod NULL — bu da ayrı bir sorun ama spec kapsamı dışı)
2. Kullanıcı protokol uygulama butonuna basar → `hizli_uygulama` çalışır
3. Stok düşer, uygulama_log NULL etken_kod ile yazılır
4. `gorev_log` güncellenmez → UI "tamamlanmadı" gösterir
5. `protokol_eksik_tara` uygulama_log'a yazılan kaydı bulur (L9326 fallback) ama `kapatan_ref` set edilmediği için protokol eşleştirmesi de yarım kalır

---

## 3. Önerilen Çözüm

### 3.1 BUG-060a Fix: `hizli_uygulama` RPC'ye `gorev_log` UPDATE ekle

**Migration:** `supabase/migrations/20260610000001_bug060_hizli_uygulama_gorev_log.sql`

**Strateji:** Eşleşen bekleyen görevi bul ve kapat. Eşleştirme iki katmanlı:
1. **Birincil:** `etken_kod` biliniyorsa → en yakın tarihli bekleyen görevi eşle
2. **Fallback:** `etken_kod` NULL ise → aynı hayvanın son 30 gün içindeki ILAC/ASI/VITAMIN/PROTOKOL görevlerinden en yakın tarihli olanı eşle

**SQL:**
```sql
-- BUG-060a fix: hizli_uygulama artık eşleşen bekleyen gorev'i atomik kapatır
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_stok record;
  v_etken text;
  v_id uuid;
  v_kalan numeric;
  v_gorev_id text;
  v_gorev_guncellendi boolean := false;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- Stok düşüm
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  -- BUG-060a: eşleşen bekleyen gorev'i kapat
  IF v_etken IS NOT NULL THEN
    -- Etken kodu biliniyor: en yakın tarihli bekleyen görevi kapat
    SELECT id INTO v_gorev_id
    FROM public.gorev_log
    WHERE hayvan_id = p_hayvan_id
      AND etken_kod = v_etken
      AND tamamlandi = false
      AND iptal = false
      AND hedef_tarih >= CURRENT_DATE - 30
      AND hedef_tarih <= CURRENT_DATE + 7
    ORDER BY ABS(hedef_tarih - CURRENT_DATE)
    LIMIT 1;
  ELSE
    -- Etken kodu bulunamadı: en son bekleyen ilaç/aşı/vitamin görevini kapat (güvenli fallback)
    SELECT id INTO v_gorev_id
    FROM public.gorev_log
    WHERE hayvan_id = p_hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN ('ILAC', 'ASI', 'VITAMIN', 'PROTOKOL')
      AND hedef_tarih >= CURRENT_DATE - 30
      AND hedef_tarih <= CURRENT_DATE + 7
    ORDER BY hedef_tarih ASC
    LIMIT 1;
  END IF;

  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = 'uygulama_log:' || v_id::text
    WHERE id = v_gorev_id;
    v_gorev_guncellendi := true;
  END IF;

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0),
    'gorev_guncellendi', v_gorev_guncellendi,
    'gorev_id', v_gorev_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.hizli_uygulama(text, text, numeric, text, text, text) TO anon, authenticated;
```

**Simetri:** `hizli_uygulama_geri_al` zaten `kapatan_ref` üzerinden görevi geri açıyor (L9350-9355) — bu fix geri alma simetrisini korur.

### 3.2 BUG-060b Fix: `_etken_kod_bul` vitamin sınıf eşleşmesi

**Migration:** Aynı dosyada (`20260610000001_bug060_etken_kod_vitamin.sql` adıyla, veya tek dosyada birleşik)

**Strateji:** "E Vit" kontrolünü genişlet:
1. `v_class_name` "Yağda Eriyen" içeriyorsa → E_VIT
2. `v_active_ing` "E Vitamini" içeriyorsa → E_VIT
3. Mevcut fallback'ler korunur (yeldif, e vit stok adı)
4. Ek güvenlik: gelecekte farklı vitamin preparatları eklense de `v_class_name` "vitamin" içeriyorsa E_VIT sayılabilir (ama sadece E vitamini için; B/C/D vitaminleri için ayrı etken_kod gerekli)

**SQL (sadece E_VIT bloğu değişir, diğerleri aynen kalır):**
```sql
-- BUG-060b fix: "Yağda Eriyen Vitaminler" class_name'i artık E_VIT olarak tanınıyor
  IF v_class_name ILIKE '%Yağda Eriyen%'           -- CAROFERTIN-E ve benzerleri
     OR v_class_name ILIKE '%E Vit%'                -- mevcut fallback
     OR v_active_ing ILIKE '%E Vitamini%'           -- active_ingredient bazlı
     OR v_stok_ad ILIKE '%yeldif%'                 -- mevcut fallback
     OR v_stok_ad ILIKE '%e vit%'                  -- mevcut fallback
  THEN RETURN 'E_VIT'; END IF;
```

**Etki:** CAROFERTIN-E ve gelecekte eklenecek tüm E vitamini preparatları artık doğru eşleşecek. Diğer etkenler etkilenmez.

---

## 4. Uygulama Planı

### 4.1 Adım sırası

| # | Adım | Araç | Süre |
|---|------|------|------|
| 1 | Migration dosyasını yaz (`20260610000001_bug060_hizli_uygulama_gorev_log.sql`) | `write` | 5 dk |
| 2 | Ground truth'taki `hizli_uygulama` ve `_etken_kod_bul` fonksiyonlarını yeni kodla değiştir | `edit` | 5 dk |
| 3 | `git add` + commit (`fix(BUG-060): hizli_uygulama artık gorev kapatıyor + E vitamini etken kodu tanınıyor`) | `shell` | 2 dk |
| 4 | `supabase_migrate` ile SQL'i canlı DB'ye deploy et | MCP | 1 dk |
| 5 | Test: 135 numaralı hayvana yeni E vitamini uygulaması yap → `gorev_log.tamamlandi=true` doğrula | `supabase_query` | 5 dk |
| 6 | Test: `_etken_kod_bul('99e2349b-...')` → 'E_VIT' dönmeli | `supabase_rpc` | 1 dk |
| 7 | Regression: görevler sekmesinden `gorev_tamamla` hâlâ çalışıyor mu? | `supabase_rpc` | 2 dk |
| 8 | Spec'i "ÇÖZÜLDÜ" olarak işaretle, commit + push | `edit` + `shell` | 3 dk |

**Toplam tahmini süre:** 25-30 dakika

### 4.2 Ground truth senkronizasyonu kritik

Migration dosyası yazıldıktan sonra **aynı anda** `99999999999999_ground_truth.sql` de güncellenmeli. Aksi halde:
- `gitnexus analyze` tutarsızlık yakalar
- Sonraki geliştirici eski kodu görür, geri alır
- `supabase_migrate` ile deploy edilen kod ile repodaki kod farklılaşır

**Kural:** Migration + ground truth aynı commit'te, atomik.

---

## 5. Test Senaryoları

### 5.1 Senaryo A: 135 numaralı hayvan, E vitamini, normal akış (BUG-060a + 060b fix doğrulaması)

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
- `gorev_log`'daki bekleyen E vitamini kaydı `tamamlandi=true`, `tamamlanma_tarihi` set, `kapatan_ref='uygulama_log:<yeni_id>'`
- UI "tamamlandı" gösterir (hem görevler sekmesi hem detaylı geçmiş)
- `protokol_eksik_tara` artık 135 için E vitamini "eksik" göstermez

### 5.2 Senaryo B: Geri alma (simetri testi)

**Önkoşul:** Senaryo A başarıyla tamamlandı.

**Adımlar:**
1. 135'in detaylı geçmişinde yeni E vitamini uygulamasını bul
2. "Geri Al" butonuna bas
3. Onayla

**Beklenen sonuç:**
- `uygulama_log` kaydı silindi
- `stok_hareket`'e ters kayıt (iade) eklendi
- `gorev_log`'daki görev tekrar `tamamlandi=false` yapıldı (mevcut `hizli_uygulama_geri_al` mantığı sayesinde)
- UI "bekliyor" gösterir

### 5.3 Senaryo C: Regression — görevler sekmesinden tamamlama hâlâ çalışıyor mu?

**Adımlar:**
1. 135 için yeni bir bekleyen görev oluştur (veya başka hayvanda dene)
2. Görevler sekmesinden "Tamamlandı" işaretle
3. `gorev_tamamla` RPC'sini doğrudan çağır

**Beklenen sonuç:**
- `gorev_log.tamamlandi=true`
- `stok_hareket` INSERT
- `islem_log` INSERT
- 060a/060b değişiklikleri `gorev_tamamla`'yı etkilememeli

### 5.4 Senaryo D: Etken kodu NULL olan stok (edge case)

**Adımlar:**
1. `_etken_kod_bul` NULL dönen bir stok seç
2. Bu stokla hizli_uygulama çağır
3. Aynı hayvan için birden fazla bekleyen görev olduğunda hangisinin kapatıldığını kontrol et

**Beklenen sonuç:**
- Fallback mekanizması (`gorev_tipi IN ('ILAC', 'ASI', 'VITAMIN', 'PROTOKOL')`) en yakın tarihli görevi kapatır
- Birden fazla eşleşme varsa `hedef_tarih ASC` ile en eski bekleyen görev kapatılır (Mantık: "şu an vakti gelmiş olan önce yapılır")
- Hiç eşleşme yoksa `gorev_guncellendi=false` döner, ama RPC hata vermez, stok yine düşer

---

## 6. Kabul Kriterleri

- [ ] Migration dosyası `supabase/migrations/20260610000001_*.sql` yazıldı
- [ ] Ground truth'taki `hizli_uygulama` ve `_etken_kod_bul` güncellendi (aynı commit)
- [ ] `supabase_migrate` ile canlı DB'ye deploy edildi
- [ ] Senaryo A başarılı: 135 için `uygulama_log.etken_kod='E_VIT'` ve `gorev_log.tamamlandi=true`
- [ ] Senaryo B başarılı: geri alma simetrisi çalışıyor
- [ ] Senaryo C başarılı: `gorev_tamamla` regression yok
- [ ] Senaryo D başarılı: edge case (etken_kod NULL) fallback çalışıyor
- [ ] `_etken_kod_bul('99e2349b-...')` çağrısı → 'E_VIT' dönüyor
- [ ] Spec dosyası "ÇÖZÜLDÜ" olarak işaretlendi
- [ ] Commit + push yapıldı

---

## 7. Riskler ve Önlemler

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Migration hatası → canlı DB bozulur | Düşük | Yüksek | `supabase_migrate` öncesi SQL syntax kontrolü, mümkünse staging |
| `gorev_log` UPDATE yanlış görevi kapatır (yanlış eşleşme) | Orta | Yüksek | `hedef_tarih` filtresi (-30 +7 gün) + `gorev_tipi` filtresi + LIMIT 1 ile sınırla |
| `gorev_tamamla` artık çalışmıyor (regression) | Çok düşük | Orta | Senaryo C testi zorunlu |
| Birden fazla bekleyen görev varsa hangisi kapatılacak belirsiz | Orta | Düşük | Dokümante edildi: en yakın tarihli, sonra en eski |
| `_etken_kod_bul` değişikliği diğer etkenleri etkiler | Çok düşük | Orta | Sadece E_VIT bloğu değişti, diğerleri aynen kaldı |
| 135 için **geçmiş** orphan kayıtlar (etken_kod NULL uygulama_log'lar) | Kesin | Düşük | Yeni uygulama bunları etkilemez, orphan kalır — ayrı temizlik task'ı gerekebilir |

---

## 8. Gelecek İyileştirmeler (Spec Kapsamı Dışı)

1. **`gorev_log` oluşturulurken `etken_kod` her zaman set edilsin** — şu an NULL olarak oluşabiliyor, bu da 060b fix'in tam faydasını sınırlıyor
2. **`protokol_eksik_tara` L9326 fallback'i** — uygulama_log'a yazılan kaydı geçici "tamamlandı" sayıyor ama `kapatan_ref` set edilmiyor. Bu fallback ya kaldırılmalı ya da daha güvenli hale getirilmeli
3. **Orphan `uygulama_log` kayıtları için temizlik scripti** — 135'teki 04:30 ve 04:50 kayıtları gibi etken_kod NULL olan kayıtlar raporlanmalı
4. **Stok düşüşü + görev kapatma transaction'ı** — PL/pgSQL zaten tek transaction içinde çalışıyor ama `islem_log` snapshot'ı eklemek audit trail için faydalı olur

---

## 9. Referanslar

- `js/ui.js:1080-1102` — `_hayvanHizliUygulaKaydet` (handler)
- `js/ui.js:940-970` — `_protokolUygulaKaydet` (handler)
- `js/ui.js:3982` — görevler sekmesi `gorev_tamamla` çağrısı
- `supabase/migrations/99999999999999_ground_truth.sql:6556-6645` — `gorev_tamamla` RPC
- `supabase/migrations/99999999999999_ground_truth.sql:9169-9224` — `_etken_kod_bul` RPC
- `supabase/migrations/99999999999999_ground_truth.sql:9256-9298` — `hizli_uygulama` RPC (BUG-060a kaynağı)
- `supabase/migrations/99999999999999_ground_truth.sql:9320-9395` — `hizli_uygulama_geri_al` (simetri için)
- `supabase/migrations/99999999999999_ground_truth.sql:9300-9350` — `protokol_eksik_tara` (060b'yi gören scanner)
- `.claude/knowledge/bugs.md` — eski BUG-060 kaydı (UUID cast fix, e0f563d)

---

**Spec durumu:** 📋 Yazıldı, onay + uygulama bekliyor
