# KPI Hesaplama Metodolojisi — Akademik & Endüstri Standardı

**Kaynaklar:**
- vetpsk/Kulkarni-et-al.-2023 (GitHub R reposu)
- Kentucky Üniversitesi: "Ways to Measure Dairy Reproductive Performance"
- ADAS: "Key Performance Indicators for Monitoring Fertility"
- Tennessee Üniversitesi: "Back to the Breeding Basics"
- UGA: "Dairy Reproduction Benchmarks"

---

## Standard Reproduction KPIs

### 1. Conception Rate (CR) — Gebelik Başarı Oranı

```
CR = Pregnant / Bred × 100
```

- Tohumlanan hayvanlardan kaçı gebe kaldı?
- **Filtre:** Sadece sonucu belli olan tohumlamalar (Pregnant veya Open)
- Bekliyor (unknown outcome) dahil edilmez
- Bizdeki karşılığı: `sonuc IN ('Gebe','Doğum Yaptı') / sonuc IN ('Gebe','Doğum Yaptı','Boş')`

### 2. Heat Detection Rate (HDR) — Kızgınlık Tespit Oranı

```
HDR = Inseminated / Eligible × 100
```

- 21 günlük pencerede, tohumlanabilir hayvanların kaçı tohumlandı?
- **Eligible (Uygun):** VWP'yi geçmiş, gebe olmayan, kuruda olmayan dişiler
- İnsemination Rate olarak da bilinir

### 3. Pregnancy Rate (PR) — Gebelik Oranı

```
PR = Pregnant / Eligible × 100
```

- 21 günlük pencerede, uygun hayvanların kaçı gebe kaldı?
- **PR = HDR × CR** (matematiksel ilişki)
- Örnek: 40 uygun inek, 20'si tohumlandı, 10'u gebe → PR = 10/40 = %25
- En kapsamlı repro metriğidir — hem ısı tespitini hem gebelik başarısını birleştirir

### 4. 21-Day Pregnancy Rate

```
21-Day PR = (Pregnancies in 21-day window) / (Eligible cows in that window)
```

- DairyComp 305'in `BREDSUM\E` komutu bu metriği üretir
- Son 2 cycle (42 gün) yıllık ortalamaya DAHİL EDİLMEZ — çünkü henüz sonucu bilinmeyen tohumlamalar olabilir
- **Pregnancy rate 42 gün öncesine kadar**, insemination rate düne kadar hesaplanır

### 5. Services Per Conception (SPC)

```
SPC = 1 / CR
```

- Örn: CR = %40 ise SPC = 2.5
- Gebelik başına kaç tohumlama yapıldığı

---

## Animal Filtering Rules

### Voluntary Waiting Period (VWP)
- Doğumdan sonra tohumlamaya başlamadan önce beklenen süre
- **Standart:** 50-60 gün (sütçü ineklerde)
- VWP'yi doldurmamış hayvanlar **Eligible DEĞİLDİR**

### Eligible Tanımı (BoviSync/DairyComp Standardı)
Bir hayvanın 21-gün PR hesabına dahil olması için:
1. Dişi olmalı
2. Aktif olmalı (satılmamış, ölmemiş)
3. **VWP'yi doldurmuş olmalı** (doğumdan sonra ≥50-60 gün)
4. **Gebe olmamalı** (confirmed pregnant)
5. Kuru dönemde olmamalı (bazı sistemler kuru inekleri de sayar — tartışmalı)
6. 21 günlük pencerede en az 1 gün "eligible" olmalı

### Lactation/DIM Filtreleri (Kulkarni-et-al-2023)
- Laktasyon sayısı filtrelemesi: `LACT > 0` (ilk laktasyon hariç tutulabilir)
- DIM filtrelemesi: `DIM >= VWP AND DIM <= 300` (aşırı uzun open günler hariç)
- `CDAT > 0` (buzağılama tarihi olanlar)

---

## Cohort (Kohort) Tanımları

| Kohort | Tanım | Kullanım |
|--------|-------|----------|
| Parite (Lactation #) | 1, 2, 3+ | Düve vs inek karşılaştırması |
| Sezon | İlkbahar/Yaz/Sonbahar/Kış | Sıcaklık stresi etkisi |
| VWP grubu | 50, 60, 70+ gün | Protokol uyumu |
| Teknoloji | TAI vs ısı tespiti | Yöntem başarısı |
| Boğa/Sperma | Sire bazlı | Genetik seçilim |

---

## PostgreSQL-Ready WHERE Clauses (Projemiz İçin)

```sql
-- Eligible hayvanlar (21-gün PR için)
WHERE h.cinsiyet = 'Dişi'
  AND h.durum = 'Aktif'
  AND h.id NOT IN (SELECT hayvan_id FROM gebe_hayvanlar)  -- gebe değil
  AND EXISTS (
    SELECT 1 FROM dogum d 
    WHERE d.anne_id = h.id 
      AND d.tarih < CURRENT_DATE - 50  -- VWP: 50 gün
      AND d.tarih > CURRENT_DATE - 365  -- son 1 yıl içinde doğum
  )

-- Sadece sonuçlanmış tohumlamalar (Bekliyor hariç)
WHERE t.sonuc IN ('Gebe', 'Doğum Yaptı', 'Boş')

-- 42 gün öncesine kadar gebelik sonucu (son 2 cycle hariç)
WHERE t.tarih < CURRENT_DATE - 42

-- Servis numarasına göre gruplama
GROUP BY t.deneme_no
```

---

## Key Takeaways

| Kural | Projeye Uyarlama |
|-------|-----------------|
| VWP = 50 gün | `dogum.tarih + 50 gün < NOW()` filtresi |
| Eligible = gebe değil + VWP geçmiş | Yeni view/RPC ile hesaplanabilir |
| Son 42 gün hariç | `BREDSUM\E`'nin standardı — güvenilir veri için |
| PR = HDR × CR | İki metriğin çarpımı PR'ı vermeli |
| 21-gün pencereleri | 21'er günlük dilimlere bölerek trend analizi |
| Bekliyor dahil edilmez | Mevcut implementasyon doğru |
