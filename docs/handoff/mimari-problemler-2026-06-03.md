# Mimari Problemler — Handoff Belgesi
**Tarih:** 2026-06-03  
**Hazırlayan:** Claude Sonnet (araştırma oturumu)  
**Devralacak:** Opus  
**Konu:** Sessiz kızgınlık sistemi + doğum sonrası görev mimarisi — tespit edilen sorunlar ve çözüm önerileri

---

## 1. Bağlam — Ne Araştırıldı

Kullanıcı dashboard'da çok sayıda yanlış VETERINER_KONTROL görevi gördü ("0 gündür üreme aktivitesi yok", buzağılar dahil). Araştırma bu bulgularla derinleşti ve kökten mimari bir probleme ulaştı.

---

## 2. Mevcut Sistem Akışı

### Sessiz Kızgınlık Tespiti

```
stat_suru_ozet() çağrılır
  → sessiz_hayvanlar_gorev_olustur() tetiklenir (side effect)
    → v_eligible view'dan 55+ gün sessiz hayvanlar çekilir
    → gorev_log'a VETERINER_KONTROL INSERT atılır
```

**v_eligible view kriterleri:**
- Dişi, Aktif, kısır değil
- grup ILIKE '%buzağı%' veya '%küçük%' DEĞİL
- dogum_tarihi <= bugün - 13 ay (veya NULL — bu sorunlu, aşağıda)
- Aktif gebe tohumlama yok
- Aktif case yok
- son_dogum.tarih IS NULL VEYA son_dogum.tarih < bugün - 55

**sessiz_gun hesabı (v_eligible içinde):**
```sql
CASE
  WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
  ELSE CASE
    WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
    ELSE NULL
  END
END
```

### Doğum Akışı

```
dogum_kaydet() RPC çağrılır  [NOT: fonksiyon adı dogum_ekle DEĞİL]
  → dogum tablosuna INSERT
  → hayvanlar tablosuna buzağı INSERT (anne_id set edilir)
  → anne padok = 'Sağmal Padok' UPDATE
  → gorev_log'a doğum sonrası görevler INSERT (7 adet anne + 7 adet buzağı)
```

**Doğum sonrası görev şeması (anne için):**
| Gün | Görev Tipi | Açıklama |
|-----|-----------|----------|
| +0  | ILAC | Oksitosin + Ademin + Kalsiyum |
| +2  | ILAC | 2. Gün PG |
| +11 | ILAC | 11. Gün PG |
| +25 | ILAC | 25. Gün PG |
| +53 | ILAC | 53. Gün: Ademin + Yeldif |
| +54 | ILAC | 54. Gün: Yeldif |
| +58 | DIGER | ⚡ 58-63. gün kızgınlık takibi |

Kaynak tag'i: `'DOGUM-' || p_anne_id` (tüm bu görevlerde)

---

## 3. Tespit Edilen Sorunlar

### 3.1 Trigger-Based Mimari — Temel Kırılma Noktası

**Problem:** Tüm downstream görevler RPC çağrısı anında INSERT edilir. Retroaktif veri girişinde (sonradan eklenen doğumlar, geçmişten aktarılan hayvanlar) bu trigger çalışmaz → görevler hiç oluşmaz.

**Neden oldu:** 1 Haziran 2026'da toplu buzağı girişi yapıldı. Annelerin doğum kayıtları `dogum_ekle` RPC'si **kullanılmadan**, doğrudan `dogum` tablosuna (muhtemelen manuel veya ayrı bir script ile) girildi. `created_at = 2026-06-01T07:01:28` — hepsi aynı saniyede.

**Etkilenen anneler (1 Haziran batch):**
| Anne Küpe | Anne ID | Doğum Tarihi | Buzağı | Buzağı Küpe |
|-----------|---------|-------------|--------|-------------|
| 901 | 88449c15-0915-4cd3-a2ac-83c88bcecfb1 | 2026-04-08 | Dişi | 77 |
| 901 | 88449c15-0915-4cd3-a2ac-83c88bcecfb1 | 2026-04-08 | Dişi | 78 (elle girilmiş) |
| 173 | 548df203-5c9c-4620-8858-8de93ef13841 | 2026-04-14 | Dişi | 79 |
| 180 | b6053753-b612-4040-82b6-e06f4c947bb2 | 2026-04-16 | Erkek | 80 |

**Not:** 78 numaralı buzağı kullanıcı tarafından elle sisteme girilmiş. Hayvanlar tablosunda `anne_id = 88449c15` (901) doğru set edilmiş. Dogum tablosunda da `yavru_kupe = '78'` kaydı var. Ama `dogum_ekle` RPC'si çalışmadığı için 901 için hiçbir doğum sonrası görev oluşmadı.

**Soru (Opus için):** Dashboard'da "Son Doğumlar" listesinde 192→76 (19 Mart), 146→75 (19 Mart), 121→74 (19 Şubat) de görünüyor. Bunların da doğum sonrası görevleri eksik olabilir — kontrol edilmeli.

---

### 3.2 Eksik Doğum Sonrası Görevler — Acil Durum

3 anne için **hiçbir** doğum sonrası görev yok. Sadece stale görevler mevcut.

**Mevcut (yanlış) gorev_log:**
- PADOK_DEGISIM "Kuru döneme geçiş zamanı" hedef: 2026-05-18 → gebelik protokolünden kalan, anneler doğurdu, stale
- VETERINER_KONTROL "Sessiz hayvan" hedef: 2026-05-31 → yanlış hesaplanmış, stale

**Olması gereken vs bugün:**

| Görev | 901 (8 Nis) | 173 (14 Nis) | 180 (16 Nis) |
|-------|-------------|--------------|--------------|
| +0 Oksitosin | ❌ 56 gün geçti | ❌ 50 gün geçti | ❌ 48 gün geçti |
| +2 PG | ❌ geçti | ❌ geçti | ❌ geçti |
| +11 PG | ❌ geçti | ❌ geçti | ❌ geçti |
| +25 PG | ❌ geçti | ❌ geçti | ❌ geçti |
| **+53 Ademin+Yeldif** | ❌ **31 Mayıs — geçti** | ⚠️ **6 Haziran — 3 GÜN** | ⚠️ **8 Haziran — 5 GÜN** |
| **+54 Yeldif** | ❌ **1 Haziran — geçti** | ⚠️ **7 Haziran — 4 GÜN** | ⚠️ **9 Haziran — 6 GÜN** |
| **+58 Kızgınlık takibi** | ⚠️ **5 Haziran — 2 GÜN** | ⚠️ **11 Haziran** | ⚠️ **13 Haziran** |

**⚠️ Acil:** 173 ve 180 için 53. ve 54. gün vitamin görevleri 3-6 gün içinde. 901 için kızgınlık takibi 2 gün içinde.

---

### 3.3 v_eligible Sessiz_gun Formülü Eksikliği

**Problem:** `sessiz_gun` hesabında `son_dogum.tarih` kullanılmıyor. Post-partum ineğin (son tohumlama/kızgınlık yok, kendi dogum_tarihi NULL) sessiz_gun'u NULL çıkıyor → COALESCE(NULL, 9999) → yanlış görünüyor.

```sql
-- MEVCUT (eksik):
CASE
  WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
  ELSE CASE
    WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
    ELSE NULL  -- ← 901 buraya düşüyor → 9999
  END
END

-- OLMASI GEREKEN:
CASE
  WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
  WHEN son_dogum.tarih IS NOT NULL    THEN CURRENT_DATE - son_dogum.tarih  -- ← eksik
  WHEN h.dogum_tarihi IS NOT NULL     THEN CURRENT_DATE - h.dogum_tarihi
  ELSE NULL
END
```

**Etki:** 901 şu an sessiz_gun=9999 → dashboard "Hiç kayıt yok" gösteriyor. Formula fix sonrası sessiz_gun=56 → "56 gündür sessiz" → doğru.

---

### 3.4 VETERINER_KONTROL Stale Görevler — 4 Hayvan

| Küpe | Sorun | Eylem |
|------|-------|-------|
| 78 | Süt İçen Buzağı, 8 haftalık — eski v_eligible buzağı filtresi yoktu | SİL |
| Test buzağı cabbiş (H000088) | Süt İçen Buzağı, 8 günlük — aynı | SİL |
| 173 | Dogum kaydı retroaktif girildi, 31 Mayıs'ta henüz yoktu | SİL |
| 180 | Aynı | SİL |

**901 için:** VETERINER_KONTROL "0 gündür" stale (sessiz_gun=NULL iken oluştu). Formula fix sonrası 901 zaten doğru şekilde 56 gündür sessiz olarak tekrar görev alacak. Silinmeli.

---

### 3.5 "0 Gündür" Açıklama Hatası

`sessiz_hayvanlar_gorev_olustur` fonksiyonunda:
```sql
-- BUG (ground_truth satır ~8704):
format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', 
  COALESCE(v_rec.sessiz_gun, 0),  -- ← NULL → 0
  v_rec.kupe_no)

-- FIX:
CASE 
  WHEN v_rec.sessiz_gun IS NULL 
    THEN format('Sessiz hayvan: hiç aktivite kaydı yok (%s)', v_rec.kupe_no)
  ELSE 
    format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', v_rec.sessiz_gun, v_rec.kupe_no)
END
```

---

### 3.6 NULL dogum_tarihi → v_eligible'da Yanlış Dahil

**Problem:** `(h.dogum_tarihi IS NULL OR h.dogum_tarihi <= CURRENT_DATE - INTERVAL '13 months')` — NULL dogum_tarihi'ni yaşı bilinmeyen buzağılar için de pass ettiriyor. Ama bu aynı zamanda olması gereken bir tolerans — grup adı "Düve (Büyük)" olan hayvanların dogum_tarihi girilmemiş olabilir ve bunlar meşru adaylar.

**Mevcut pratik:** Bu tolerans doğru bırakılabilir, asıl sorun açıklama "0 gündür" (3.5 ile çözülür).

---

### 3.7 Ürün Eksikliği — Mevcut Buzağıyı Anne ile Bağlama

**Problem:** `dogum_ekle` RPC'si hem dogum kaydını hem buzağıyı aynı anda oluşturuyor. Sistemde zaten kayıtlı (sonradan manuel eklenen) bir buzağıyı mevcut bir anne ile ilişkilendirme yolu yok.

**Kullanıcının sözleri:** "ben manuel bir buzağı eklediğimde sistemde var olan bir anne ile ancak dogum kaydı ile eşleme yapabiliyorum. yaşı büyük olan buzağıları doğal bir şekilde ilişkilendiremiyoruz annelerle"

**İdeal çözüm:** `retroaktif_dogum_baglanti(anne_id, buzagi_id, dogum_tarihi)` fonksiyonu:
- Dogum kaydını oluşturur (dogum tablosu)
- Buzağının `anne_id`'sini set eder (hayvanlar tablosu)
- Geçmişte kalan görevleri atlar, sadece bugünden itibaren gelen görevleri oluşturur

---

## 4. Mimari Değerlendirme

### Trigger-Based vs Time-Based Karşılaştırma

| | Trigger-Based (mevcut) | Time-Based (önerilen) |
|---|---|---|
| **Nasıl çalışır** | RPC çağrısında görev INSERT'leri ateşlenir | Görevler `dogum.tarih + N` hesabından türetilir |
| **Retroaktif giriş** | ❌ Görevler kaybolur | ✅ Her zaman doğru |
| **Karmaşıklık** | Düşük (bir kere yazılır) | Yüksek (view/fonksiyon karmaşık) |
| **Esneklik** | Düşük (protokol değişince tüm geçmiş değişmez) | Yüksek (protokol değişince otomatik güncellenir) |
| **Mevcut sistem** | gorev_log tablosuna yazılır | Hala gorev_log'a yazılabilir veya on-the-fly |

**Kullanıcının önerisi:** Time-based tasarım daha sağlam. Ancak mevcut sistemi komple dönüştürmek büyük iş — önce acil düzeltmeler, sonra kademeli geçiş.

---

## 5. Gerekli Eylemler (Öncelik Sırasıyla)

### Acil (Bu Oturumda)

**A. gorev_log Temizliği**

**ÖNEMLİ:** Sistem `DELETE` değil `UPDATE SET iptal = true` kullanıyor (ground_truth satır 2347, 8791). Hard DELETE yapma.

**ÖNCE DOĞRULA:** H000088 ID'sini canlıdan kontrol et:
```sql
SELECT id, kupe_no, grup FROM hayvanlar WHERE id = 'H000088';
-- Sıfır satır dönerse ID yanlış — önce doğru ID'yi bul
```

```sql
-- 5 stale VETERINER_KONTROL görevi — iptal et
UPDATE gorev_log 
SET iptal = true
WHERE gorev_tipi = 'VETERINER_KONTROL' 
  AND tamamlandi = false
  AND iptal = false
  AND hayvan_id IN (
    'daaa2054-fa15-41fe-916c-237a925c789e',  -- 78 (Süt İçen Buzağı)
    'H000088',                                -- Test buzağı cabbiş (ID'yi ÖNCE doğrula!)
    '548df203-5c9c-4620-8858-8de93ef13841',  -- 173
    'b6053753-b612-4040-82b6-e06f4c947bb2',  -- 180
    '88449c15-0915-4cd3-a2ac-83c88bcecfb1'   -- 901 (0 gün description)
  );

-- 3 stale PADOK_DEGISIM "Kuru dönem" görevi — iptal et
UPDATE gorev_log
SET iptal = true
WHERE gorev_tipi = 'PADOK_DEGISIM'
  AND aciklama LIKE '%Kuru döneme geçiş%'
  AND tamamlandi = false
  AND iptal = false
  AND hayvan_id IN (
    '548df203-5c9c-4620-8858-8de93ef13841',  -- 173
    'b6053753-b612-4040-82b6-e06f4c947bb2',  -- 180
    '88449c15-0915-4cd3-a2ac-83c88bcecfb1'   -- 901
  );
```

**B. Eksik Doğum Sonrası Görev Oluşturma**

3 anne için gün 53, 54, 58 görevlerini ekle (geçmiş günler atlanır). `kaynak` kolonu mevcut (ground_truth satır 60). `gorev_log.id` TEXT tipinde, `gen_random_uuid()` otomatik cast edilir.

**Açıklama metinleri ground_truth satır 687-693'ten birebir alınmıştır.**

**Idempotent guard: mevcut görev varsa INSERT yapma.**

```sql
-- 173 (doğum: 2026-04-14) — 3 görev
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
SELECT gen_random_uuid(), '548df203-5c9c-4620-8858-8de93ef13841', v.tip, v.aciklama, v.tarih, false, 'DOGUM-548df203-5c9c-4620-8858-8de93ef13841'
FROM (VALUES
  ('ILAC',  '53. Gün: Ademin + Yeldif',       DATE '2026-06-06'),
  ('ILAC',  '54. Gün: Yeldif',                DATE '2026-06-07'),
  ('DIGER', '⚡ 58-63. gün kızgınlık takibi', DATE '2026-06-11')
) AS v(tip, aciklama, tarih)
WHERE NOT EXISTS (
  SELECT 1 FROM gorev_log g
  WHERE g.hayvan_id = '548df203-5c9c-4620-8858-8de93ef13841'
    AND g.aciklama = v.aciklama
    AND g.tamamlandi = false AND g.iptal = false
);

-- 180 (doğum: 2026-04-16) — 3 görev
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
SELECT gen_random_uuid(), 'b6053753-b612-4040-82b6-e06f4c947bb2', v.tip, v.aciklama, v.tarih, false, 'DOGUM-b6053753-b612-4040-82b6-e06f4c947bb2'
FROM (VALUES
  ('ILAC',  '53. Gün: Ademin + Yeldif',       DATE '2026-06-08'),
  ('ILAC',  '54. Gün: Yeldif',                DATE '2026-06-09'),
  ('DIGER', '⚡ 58-63. gün kızgınlık takibi', DATE '2026-06-13')
) AS v(tip, aciklama, tarih)
WHERE NOT EXISTS (
  SELECT 1 FROM gorev_log g
  WHERE g.hayvan_id = 'b6053753-b612-4040-82b6-e06f4c947bb2'
    AND g.aciklama = v.aciklama
    AND g.tamamlandi = false AND g.iptal = false
);

-- 901 (doğum: 2026-04-08) — 53./54. gün geçti, sadece 58. gün
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
SELECT gen_random_uuid(), '88449c15-0915-4cd3-a2ac-83c88bcecfb1', 'DIGER', '⚡ 58-63. gün kızgınlık takibi', DATE '2026-06-05', false, 'DOGUM-88449c15-0915-4cd3-a2ac-83c88bcecfb1'
WHERE NOT EXISTS (
  SELECT 1 FROM gorev_log g
  WHERE g.hayvan_id = '88449c15-0915-4cd3-a2ac-83c88bcecfb1'
    AND g.aciklama = '⚡ 58-63. gün kızgınlık takibi'
    AND g.tamamlandi = false AND g.iptal = false
);
```

`supabase_migrate` aracıyla çalıştır (raw SQL).

### Orta Vadeli (Bu Oturumda Yapılabilir)

**C. v_eligible sessiz_gun formula fix**
Migration olarak:
```sql
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT
  h.id, h.kupe_no, h.grup, h.padok,
  son_dogum.tarih AS son_dogum_tarihi,
  CURRENT_DATE - son_dogum.tarih AS dogum_gun,
  son_aktivite.tarih AS son_aktivite_tarihi,
  CASE
    WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
    WHEN son_dogum.tarih IS NOT NULL    THEN CURRENT_DATE - son_dogum.tarih  -- ← YENİ
    WHEN h.dogum_tarihi IS NOT NULL     THEN CURRENT_DATE - h.dogum_tarihi
    ELSE NULL
  END AS sessiz_gun
FROM public.hayvanlar h
-- ... (geri kalan WHERE aynı kalır)
```

**D. sessiz_hayvanlar_gorev_olustur açıklama fix + kaynak ekleme**

Mevcut INSERT'te `kaynak` kolonu da eksik — aynı migration'da ekle:

```sql
-- ground_truth ~satır 8701-8706
INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
VALUES (
  gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
  CASE 
    WHEN v_rec.sessiz_gun IS NULL 
      THEN format('Sessiz hayvan: hiç aktivite kaydı yok (%s)', v_rec.kupe_no)
    ELSE 
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', v_rec.sessiz_gun, v_rec.kupe_no)
  END,
  CURRENT_DATE, false,
  'SESSIZ-' || v_rec.id  -- kaynak eklendi
);
```

**E. ground_truth.sql sync**
C ve D değişikliklerini ground_truth'a yansıt.

### Uzun Vadeli (Backlog)

**F. `dogum_sonrasi_gorev_tureti(anne_id, dogum_tarihi)` RPC**
Retroaktif doğum girişleri için çağrılabilir. Geçmişteki görevleri atlar, sadece bugünden itibaren gelen görevleri oluşturur. Mevcut görev yoksa oluşturur (idempotent).

**G. `retroaktif_dogum_baglanti(anne_id, buzagi_id, dogum_tarihi)` RPC**
Mevcut bir buzağıyı anne ile ilişkilendirmek için. dogum kaydı oluşturur, buzağının anne_id'sini set eder, F'yi çağırır.

**H. Diğer retroaktif doğumları kontrol et**
192→76 (19 Mart), 146→75 (19 Mart), 121→74 (19 Şubat) — doğum sonrası görevleri eksik olabilir. Aynı pattern.

---

## 6. Veritabanı Referans Bilgileri

### İlgili Tablolar
- `hayvanlar`: id, kupe_no, grup, padok, cinsiyet, durum, kisir, dogum_tarihi, anne_id
- `dogum`: id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, created_at, hekim_id, dogum_kg, baba_bilgi
- `gorev_log`: id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak (kontrol et)
- `tohumlama`: hayvan_id, tarih, sonuc, deneme_no, sperma
- `kizginlik_log`: hayvan_id, tarih, olusturma, belirti, notlar

### İlgili RPC'ler
- `dogum_kaydet(p_anne_id, p_tarih, p_cins, p_kupe, p_tip, p_hekim_id, p_kg, p_baba)` — ground_truth ~satır 641 (**dogum_ekle DEĞİL**)
- `sessiz_hayvanlar_listele(p_padok, p_min_gun=55)` — ground_truth ~satır 8677
- `sessiz_hayvanlar_gorev_olustur()` — ground_truth ~satır 8693
- `stat_suru_ozet(p_padok, p_son_donem)` — ground_truth ~satır 8540 (sessiz_hayvanlar_gorev_olustur'u çağırır)

### İlgili View'lar
- `v_eligible` — ground_truth ~satır 8641
- `cozulmemis_kizginlik_view` — aktif kızgınlık uyarı şeridi için (farklı konu, bu oturumda sorun yok)

### Canonical Referans
`supabase/migrations/99999999999999_ground_truth.sql` — her zaman bu dosyayı baz al, ara migration'lara bakma.

---

## 7. Bu Oturumda Yapılmayanlar

- Eylem A ve B için kullanıcı onayı alınmadı (dosya oluşturma talebi geldi)
- Diğer retroaktif doğumlar (192, 146, 121) araştırılmadı
- v_eligible formula migration yazılmadı
- gorev_log `kaynak` kolonu varlığı doğrulanmadı

---

## 8. Önerilen Başlangıç Noktası (Opus İçin)

1. `gorev_log` tablosunun kolonlarını doğrula (`kaynak` var mı?)
2. Eylem A'yı (stale görev silme) çalıştır → kullanıcı onayı al
3. Eylem B'yi (eksik görev ekleme) çalıştır → 173 ve 180 için acil
4. Eylem C+D+E'yi (migration + ground_truth) uygula
5. 192, 146, 121 anneleri için aynı pattern'i kontrol et

**tools-bank MCP araçları kullanılabilir:** `supabase_query`, `supabase_migrate`, `supabase_rpc`  
**Canonical referans:** `99999999999999_ground_truth.sql`  
**RPC imzaları:** `.claude/rpc-reference.md`
