# Üreme İstatistikleri — Mimari Durum ve Yol Haritası

**Oluşturulma:** 2026-05-31
**Son güncelleme:** 2026-05-31
**Durum:** Araştırma tamamlandı — 2 karar verildi (VWP, 42 gün), implementasyon bekliyor

---

## 1. Mevcut Mimari

### Veri Akışı

```
tohumlama (245 kayıt, ham tablo)
  │  her satır = 1 tohumlama denemesi
  │  alanlar: hayvan_id, tarih, deneme_no, sperma, sonuc
  ↓
v_ureme_dongusu (VIEW — 127 cycle)
  │  deneme_no=1 → yeni cycle başlatır
  │  cycle sonucu: Gebe > Abort > Bekliyor > Boş (bool_or öncelik)
  │  sperma attribution: gebe_sperma (başarılı) / son_sperma (başarısız)
  ↓
stat_suru_ozet (RPC — JSON döner)
  │  cycles CTE → son dönem filtresi
  │  hayvan_stat CTE → DISTINCT ON son cycle
  │  hayvan_ozet + cycle_ozet + kategori + sperma_top5 + deneme
  ↓
ui.js _applySuruStatHtml (kart gösterimi)
  │  sadece render, hesap yok
```

### Dosyalar

| Dosya | Rol |
|-------|-----|
| `supabase/migrations/20260530210000_v_ureme_dongusu.sql` | Cycle detection view |
| `supabase/migrations/20260530220000_stat_suru_ozet_v2.sql` | İstatistik RPC |
| `supabase/migrations/99999999999999_ground_truth.sql` | Canonical referans |
| `js/ui.js` (satır 707-751) | Dashboard render |

### Cycle Tespiti Nasıl Çalışıyor

Tohumlama tablosundaki `deneme_no` alanı cycle sınırını belirler:
- `deneme_no = 1` → yeni cycle başlangıcı
- `deneme_no > 1` → mevcut cycle'ın devam denemesi

Window function ile cycle_no atanır:
```sql
SUM(CASE WHEN deneme_no = 1 THEN 1 ELSE 0 END)
  OVER (PARTITION BY hayvan_id ORDER BY tarih, deneme_no)
```

Bir cycle'ın sonucu, içindeki tüm denemelerin sonuçlarından belirlenir:
- Herhangi biri Gebe/Doğum Yaptı → cycle = Gebe
- Herhangi biri Abort → cycle = Abort
- Herhangi biri Bekliyor → cycle = Bekliyor
- Hepsi Boş → cycle = Boş

### Sperma Attribution

Her cycle için **1 sperma** sayılır:
- Başarılı cycle → `gebe_sperma` (gebe bırakan denemenin sperması)
- Başarısız cycle → `son_sperma` (son denemenin sperması)

Ara denemelerdeki spermalar istatistikte görünmez. Bu bilinçli tasarım: "hayvanı gebe bırakan son spermadır, repeat'ler ara adımdır."

### Son Dönem Filtresi

"Son gebelikten sonraki tüm cycle'lar" — bir hayvan önce Gebe, sonra Boş olduysa son dönemde Boş olarak sayılır.

```sql
NOT EXISTS (
  SELECT 1 FROM v_ureme_dongusu v2
  WHERE v2.hayvan_id = v.hayvan_id
    AND v2.cycle_no > v.cycle_no
    AND v2.sonuc IN ('Gebe','Doğum Yaptı')
)
```

### Kategori Sınıflandırma

- Düve: `grup ILIKE '%düve%'` VE doğum kaydı yok
- İnek: doğum kaydı var VEYA grup inek/sağmal/kuru
- Bilinmiyor: hiçbirine uymayan

---

## 2. Doğrulanmış Çalışan Bileşenler

| Bileşen | Doğrulama |
|---------|-----------|
| Cycle tespiti (deneme_no=1) | ✅ 245 kayıt → 127 cycle, manuel kontrol edildi |
| Cycle sonuç önceliği | ✅ bool_or sırası doğru |
| Bekliyor filtreleme | ✅ Paydadan çıkarılıyor |
| Son Dönem filtresi | ✅ Matematiksel tutarlılık kontrol edildi |
| Düve/İnek ayrımı | ✅ 10 düve, 63 inek, sınıflandırma doğru |
| Frontend render | ✅ Hesap yapmıyor, sadece gösterim |

---

## 3. Bilinen Sorunlar

### 3.1 Seed Data Kalitesi (Öncelik: Yüksek)

245 tohumlama kaydının 244'ü seed data (9 Mayıs 2026 toplu import). Son dönemdeki 18 Boş cycle'dan 16'sı şüpheli — `gorev_log`'da onay kaydı yok, `payload=null`, `kullanici_notu=null`.

Bu şüpheli Boş'lar düzeltilse gebelik oranı önemli ölçüde değişir:
- Mevcut: %74.7 (62/83 cycle)
- Şüpheliler Bekliyor yapılsa: ~%93.9 (62/66 cycle)

**Aksiyon:** Her şüpheli Boş kaydı tek tek incelenmeli, gerçek gözleme dayananlar kalmalı, dayanamayanlar Bekliyor'a çevrilmeli.

Şüpheli Boş listesi: `docs/analysis/ureme-istatistik-analiz-2026-05-31.md` §1.3

### 3.2 Sperma Top 5 Gösterimi (Öncelik: Orta)

`ORDER BY oran DESC LIMIT 5` → Tüm Zamanlar'da 5/5 sperma %100 gösteriyor. Bilgi değeri sıfır.

Sorunlu spermalar (Darius %14.3, Fresh %25) asla görünmüyor. Çiftçi bu karttan hiçbir aksiyon çıkaramaz.

**Olası çözümler (henüz karar verilmedi):**
- Limit artır (top 10)
- Min 1 başarısız olan spermaları ayrı göster
- Tüm spermaları göster, sıralama seçeneği ekle
- En kötü performans gösteren spermaları da ayrı kart olarak göster

### 3.3 Demografik 1 Fark (Öncelik: Düşük)

UI'da 89 hayvan gösteriliyor ama 66+20+3+1=90. Muhtemelen bir hayvan iki kategoride sayılıyor veya durum filtresinde edge case var. Araştırılmalı.

---

## 4. Kararlar ve Açık Konular

### 4.1 PR Periyodu ✅ KARAR VERİLDİ

**Karar (2026-05-31):** PR periyodu = **25 gün** (21 değil). 23 günde kızgınlık gösteren hayvanlar başarısız sayılmayacak.

**Gerekçe:** 21 gün teorik östrus döngüsü, pratikte 23-25 güne kadar uzar. 21 gün baz alınırsa sonuçlar gerçeği yansıtmaz, teorik kalır.

**Bizim cycle'dan farkı:** Bizim cycle = bireysel hayvan tohumlama serisi. PR = sürü genelinde üreme hızı. Eğer 10 inek tohumlamaya hazır ama sadece 3'ü tohumlandıysa, bizde 3 cycle görünür. PR "10 fırsat, 1 gebe = %10" der — tohumlanmayanları da hesaba katar.

**Gereksinim:** VWP + eligible tanımı + doğum tarihi bilgisi.

**Durum:** Kavramsal olarak anlaşıldı. Önce mevcut sorunlar çözülmeli.

### 4.2 VWP (Voluntary Waiting Period — Gönüllü Bekleme Süresi) ✅ KARAR VERİLDİ

**Ne:** Doğumdan sonra kasıtlı olarak tohumlama yapılmayan süre.

**Karar (2026-05-31):** VWP = **55 gün**. İşletme standardı olarak kabul edildi.

**Mevcut durum (doğrulandı):** VWP kuralı sistemde YOK. `tohumlama_kaydet` RPC'si dogum tablosuna bakmıyor. Sadece `kizginlik_kaydet`'te 55 günlük yumuşak kontrol var (POSTPARTUM_GOZLEM sınıflandırması) — tohumlamayı engellemez.

**Uygulama tasarımı:**
- Backend: `tohumlama_kaydet` RPC'sine dogum tarih kontrolü ekle
- 55 gün geçmemişse → hata döndür (varsayılan engel)
- Frontend: onay modalı göster → "VWP dolmadı. Yine de kaydetmek istiyor musunuz?"
- Onay verilirse → RPC'ye `p_vwp_override := true` parametresiyle tekrar çağır
- Override durumunda → `islem_log`'a `VWP_OVERRIDE` tagı yaz

**VWP_OVERRIDE tag zinciri:**
- Tohumlama kaydında göster (UI'da uyarı badge)
- Hayvan o tohumlamadan gebe kalırsa → gebelik kaydında göster
- Doğan buzağıda da göster (anne erken tohumlanmıştı bilgisi)

**İstatistik faydası:**
- Eligible havuzunu doğru hesaplayabilme (VWP dolmamış = eligible değil)
- VWP öncesi vs sonrası tohumlamaların CR karşılaştırması
- PR, HDR metriklerinin altyapısı

**21-Day PR için neden lazım:** VWP dolmamış inekler "gebe kalabilecek" havuzuna dahil edilmemeli.

### 4.3 Muayene Görevleri ✅ MEVCUT + İYİLEŞTİRME

**Mevcut:** `tohumlama_kaydet` RPC'si (ground_truth.sql:1539-1542) tohumlama kaydedildiğinde otomatik olarak 21. gün ve 35. gün GEBELIK_KONTROL görevi oluşturuyor. Bu zaten çalışıyor.

**Görev tamamlanmazsa:** Ekstra escalation gerekmez — gecikmişlerde zaten görünüyor. Sorun görev escalation değil, aşağıdaki "sessiz hayvanlar" akışı ile bağlantının kurulması.

### 4.4 Sessiz Hayvanlar (60+ Gün) ✅ KARAR VERİLDİ

**Ne:** 60+ gündür eligible olup hiçbir aksiyon alınmamış (tohumlama yok, kızgınlık kaydı yok, vaka açılmamış) hayvanlar. Sessiz kızgınlık (silent heat) veya foliküler kist gibi sağlık sorunları göstergesi olabilir.

**Karar (2026-05-31):** Dashboard listesi + otomatik görev.

**Akış:**
1. Eligible + 60 gün sessiz hayvan tespit edilir
2. Dashboard'da "Sessiz Hayvanlar" listesi gösterilir
3. Otomatik "VETERİNER_KONTROL" görevi oluşturulur
4. Listeden düşme koşulları:
   - Tohumlama yapıldı → trigger: `tohumlama_kaydet`
   - Kızgınlık kaydı girildi → trigger: `kizginlik_kaydet`
   - Vaka (case) açıldı → trigger: üreme sekmesindeki tedavi akışı

**Vaka trigger nasıl çalışacak:** Mevcut tohumlama sekmesi → kızgınlık/tohumlama/tedavi akışı kullanılacak. Vaka açıldığında `cases.animal_id` üzerinden hayvan "sessiz değil, tedavi altında" olarak tanınır ve listeden düşer. Yeni trigger yazmaya gerek yok — `cases` tablosunda `animal_id` + `status = 'active'` kontrolü yeterli.

**Kritik tasarım notu:** Liste, görev ve sonuç (tedavi/boş/gebe) şu an birbirinden bihaber. Bağlantı eligible view üzerinden kurulacak: eligible = dişi + aktif + gebe değil + VWP geçmiş + kısır değil + aktif vakası yok.

### 4.5 Kısır Hayvanlar ✅ KARAR VERİLDİ

**Karar (2026-05-31):** Kısır hayvanlar istatistik hesaplamalarına dahil edilmeyecek (buzağılar gibi).

**Uygulama:** `v_ureme_dongusu` view'ına ve `stat_suru_ozet` RPC'sine `WHERE kisir = false` veya `kisir IS NOT TRUE` filtresi ekle.

### 4.6 Sperma Gösterimi ✅ KARAR VERİLDİ

**Karar (2026-05-31):** Top 5 yerine tüm spermalar gösterilecek. `LIMIT 5` kaldırılacak.

### 4.7 Mevsimsel Trend — Bekleyen İşler

**Ne:** Ay bazlı CR grafiği (Ocak %45, Temmuz %25 gibi). Yaz sıcağının üreme başarısına etkisini görmek için.

**Durum:** Acil değil, veri birikince anlamlı olacak. Bekleyen işlere kaydedildi.

### 4.8 Şüpheli Boş Kayıtlar ✅ KARAR VERİLDİ

**Karar (2026-05-31):** Tüm seed data kaynaklı şüpheli Boş tohumlamalar Bekliyor'a çevrilecek.

**Doğrulama:** Bu hayvanların hiçbirinde Gebe kaydı yok — güvenle değiştirilebilir.

**Etkilenen kayıtlar:** Tüm `created_at = 2026-05-09T07:42:46` (seed data batch) olan Boş tohumlama kayıtları. 60 günlük sessiz hayvan listesi oluşturulduğunda muayeneye gitmesi gerekenler zaten belli olacak.

### 4.9 42 Gün Kuralı (CR Zaman Penceresi) ✅ KARAR VERİLDİ

**Ne:** Son 42 gün içindeki tohumlamaları istatistik hesabından otomatik olarak hariç tut — statüden bağımsız.

**Karar (2026-05-31):** Uygulanacak. DairyComp 305 standardı.

**Mevcut durum (doğrulandı):** 42 gün kuralı sistemde YOK. `stat_suru_ozet` ve `v_ureme_dongusu`'nda tarih filtresi bulunmuyor. Sadece "Bekliyor" statüsüyle dolaylı çalışıyor.

**Neden statü yetersiz:** Birisi Bekliyor yerine yanlışlıkla Boş girerse oran hemen düşer. 42 gün kuralı tarih bazlı — insan hatasına bağlı değil.

**Uygulama:** `stat_suru_ozet` RPC'sine `WHERE tarih < CURRENT_DATE - 42` filtresi ekle (sonuçlanmış cycle'lar için). Bekliyor filtresi de kalır — ikisi birlikte çalışır.

---

## 5. Dış Görüşler

### 5.1 Gemini Tavsiyeleri (2026-05-31)

**Özet:**
- Sistem "zamana duyarlı dinamik pencerelere" bölünmeli (cohort-bazlı)
- CR hesaplamasında 35 gün filtresi şart
- 21-Day PR en kritik KPI
- VWP entegrasyonu gerekli
- Operasyonel listeler (muayene zamanı, tohumlamaya hazır) dashboard'un asıl değeri
- Düve/İnek cohort ayrımı (zaten var)
- Mevsimsel trend filtresi (ay bazlı)
- Boğa/sperma performans grafiği

**Değerlendirme:** Tavsiyelerin hepsi doğru ve sektör standardı. Ancak önce mevcut basit sistemi sağlıklı çalıştırmadan ölçeği büyütmek riskli. Aşamalı yaklaşım:
1. Mevcut veriyi temizle ve sorunları düzelt
2. Operasyonel listeler ekle (düşük efor, yüksek değer)
3. KPI'ları kademeli olarak ekle

### 5.2 Açık Kaynak & Endüstri Araştırması (2026-05-31)

**Kaynak dosyalar:** `research/ureme-istatistik-repo-arastirmasi/` (6 dosya)

**Ana bulgu:** Açık kaynak dünyasında bizim sistemimizden daha iyi bir repro analitiği YOK. Tüm gelişmiş sistemler ticari (VAS/DairyComp 305, BoviSync). Bizim `v_ureme_dongusu` + cycle tespiti + repeat breeding handling açık kaynaktan ileri.

**Sektör standardı formüller (03-kulkarni-kpi.md, 04-bovisync-vas.md):**

```
CR  = Pregnant / Bred × 100                    ← bizde var (cycle bazlı)
HDR = Inseminated / Eligible × 100             ← bizde yok
PR  = Pregnant / Eligible × 100 = HDR × CR     ← bizde yok
21-Day PR = Pregnancies / Eligible (21 günlük pencere) ← bizde yok
SPC = 1 / CR                                   ← bizde var (ort_deneme)
```

**42 gün kuralı (DairyComp 305 standardı):**
- Insemination Rate → düne kadar hesaplanır
- Pregnancy Rate → 42 gün öncesine kadar hesaplanır
- Son 42 gün (2 kızgınlık döngüsü) yıllık ortalamaya DAHİL EDİLMEZ — sonuçlanmamış tohumlamalar güvenilir değil

**Eligible (uygun hayvan) tanımı:**
1. Dişi
2. Aktif (satılmamış, ölmemiş)
3. VWP'yi doldurmuş (doğumdan sonra ≥55 gün)
4. Gebe DEĞİL
5. 21 günlük pencerede en az 1 gün eligible

**farmOS referansı (01-farmos.md):**
- Asset-Log (event-sourcing) mimarisi → bizim hayvanlar + tohumlama/dogum/islem_log ile birebir örtüşüyor
- Bizim architecture farmOS ile aynı felsefe, cycle tespiti ile daha ileri

**Hazır SQL (03-kulkarni-kpi.md'den):**

```sql
-- Eligible view prototipi
CREATE VIEW v_eligible AS
SELECT h.id, h.kupe_no, h.grup
FROM hayvanlar h
LEFT JOIN v_ureme_dongusu v ON v.hayvan_id = h.id 
  AND v.cycle_no = (SELECT MAX(cycle_no) FROM v_ureme_dongusu WHERE hayvan_id = h.id)
WHERE h.cinsiyet = 'Dişi'
  AND h.durum = 'Aktif'
  AND (v.sonuc IS NULL OR v.sonuc NOT IN ('Gebe','Doğum Yaptı'))
  AND EXISTS (
    SELECT 1 FROM dogum d WHERE d.anne_id = h.id 
    AND d.tarih < CURRENT_DATE - 55  -- VWP (işletme kararı: 55 gün)
  );
```

**Değerlendirme:** Araştırma algoritmamızın doğru olduğunu teyit etti. Eksikler net:
1. VWP filtresi (doğumdan 55 gün — karar verildi)
2. Eligible view (gebe olmayan + VWP geçmiş + aktif)
3. 21-Day PR (eligible üzerinden gebelik oranı, 42 gün hariç)
4. HDR (eligible'ların kaçı tohumlandı)

Bu eksikler mevcut altyapıya view/RPC olarak eklenebilir — mimari değişiklik gerektirmez.

---

## 6. Terimler Sözlüğü

| Terim | Açıklama |
|-------|----------|
| **Cycle** | Bir hayvanın deneme_no=1'den başlayan tohumlama serisi. 1+ deneme içerir. |
| **CR (Conception Rate)** | Sonuçlanmış tohumlamalardaki gebelik yüzdesi. Bekliyor'lar paydadan çıkar. |
| **21-Day PR (Pregnancy Rate)** | 21 günlük periyotta gebe kalabilecek hayvanların kaçının gebe kaldığı. Sürü verimliliği. |
| **VWP (Voluntary Waiting Period)** | Doğumdan sonra kasıtlı tohumlama yapılmayan süre (genelde 50-60 gün). |
| **TU (Transrektal Ultrason)** | Gebelik muayenesi. Tohumlamadan 35-40 gün sonra yapılır. |
| **KPI (Key Performance Indicator)** | Temel performans göstergesi. İşletme sağlığını ölçen kritik metrikler. |
| **HDR (Heat Detection Rate)** | Eligible hayvanların kaçının tohumlandığı. "Yeterince hayvan tohumlayabiliyor muyuz?" |
| **Eligible** | Gebe kalabilecek durumda olan hayvan: dişi + aktif + gebe değil + VWP geçmiş. |
| **Cohort** | Benzer özelliklere sahip hayvan grubu (düve/inek, mevsim, laktasyon dönemi). |
| **Son Dönem** | Hayvanın son gebeliğinden sonraki tüm cycle'lar. |
| **Seed Data** | Toplu import ile girilen test/başlangıç verileri. |
| **Silent Heat** | Sessiz kızgınlık — hayvan kızgınlık göstermeden ovulasyon yapar, tespit edilemez. |

---

## 7. Karar Özeti ve Açık Sorular

### Verilen Kararlar (2026-05-31)

- [x] VWP = **55 gün** + override mekanizması + tag zinciri
- [x] PR periyodu = **25 gün** (21 değil, 23 günde kızgınlık başarısız sayılmayacak)
- [x] 42 gün kuralı uygulanacak (DairyComp standardı)
- [x] Kısır hayvanlar istatistik dışı (buzağılar gibi)
- [x] Tüm spermalar gösterilecek (LIMIT 5 kaldırılacak)
- [x] Şüpheli Boş → Bekliyor (seed data kaynaklı, Gebe yok — güvenli)
- [x] 60+ gün sessiz hayvanlar: dashboard listesi + görev + 3 trigger (tohumlama/kızgınlık/vaka)
- [x] Mevsimsel trend: bekleyen işlere kaydedildi, acil değil
- [x] Görev escalation: gerekmez, gecikmişlerde zaten görünüyor
- [x] Muayene görevleri: 21+35 gün otomatik görev zaten mevcut

### Açık Sorular

- [ ] Demografik 1 farkın kaynağı ne? (89 vs 90 — araştırılacak)
- [ ] Eligible view'da düveler nasıl ele alınacak? (Doğum kaydı yok, yaş bazlı VWP gerekebilir — 13-15 ay)
- [ ] Sessiz hayvanlar listesinin UI'da nerede gösterileceği (dashboard kartı mı, ayrı sekme mi?)
