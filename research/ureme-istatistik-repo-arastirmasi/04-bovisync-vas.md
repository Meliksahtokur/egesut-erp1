# BoviSync & VAS/DairyComp 305 — Üreme KPI Mantığı

**Kaynaklar:**
- https://bovisync.farm/apidoc/v1/ — BoviSync API (OAS 3.0)
- https://dc-help.vas.com/ReferenceGuide/Reports/CommonReports/BREDSUM.htm — VAS BREDSUM
- https://support.bovisync.com/portal/en/kb/articles/breeding-intensity
- https://www.dairychallenge.org/pdfs/student_resources/DairyComp-Command-Reference-Guide-Rev20231103.pdf

---

## BoviSync

### API Veri Modeli

BoviSync OAS 3.0 API, OAuth2 ile korunuyor. Event (olay) tabanlı veri modeli:

**EventBulkResponse alanları:**
| Alan | Tip | Açıklama |
|------|-----|----------|
| `datetime` | datetime | Olay zamanı |
| `animal` | integer | Hayvan API ID |
| `technician` | integer | Teknisyen API ID |
| `type` | string | Olay tipi (case-sensitive) |
| `EvType` | string | Olay tipi kodu |
| `SpEvTyp` | string | Spesifik olay tipi |
| `Proto` | string | Protokol adı |
| `LinkedEvId` | integer | Bağlı olay ID'si |
| `Pen` | integer | O anki padok |
| `EART` | integer | Güncel küpe no |
| `LACT` | integer | O anki laktasyon no |
| `DIM` | integer | O anki DIM |
| `EvLoc` | string | Çiftlik/lokasyon |
| `local_date` | date | Yerel tarih |
| `details` | object | Olay tipine özel alanlar |

> Tohumlama olayı `EvType`: muhtemelen "BRED" veya "BREEDING". Gebelik kontrolü "PREGCHECK". Her çiftlik kendi event tiplerini özelleştirebiliyor.

### Eligible Tanımı

BoviSync, DairyComp 305 ile aynı mantığı kullanır. "Breeding Intensity vs Pregnancy Rate" makalesinden:

- **Conception Rate, esas repro metriğidir** — çünkü modelin dışlama kriterlerinden (exclusion criteria) etkilenmez
- DairyComp 305'in PR hesaplamasındaki varyansın ana kaynağı, **modelin dışlama kriterleridir**
- Sıkı protokol ve yüksek ilk servis CR'si olan çiftliklerde, BoviSync'in PR değeri DairyComp 305 ile aynı çıkar

---

## VAS / DairyComp 305

### BREDSUM Komutu

```
BREDSUM        → tüm sürü, son 365 gün, sadece inekler
BREDSUM\Y      → sadece düveler (youngstock)
BREDSUM\D      → tarih aralığı sorar
BREDSUM\D180   → son 180 gün
BREDSUM\B      → servis numarasına göre (by times bred)
BREDSUM\E      → 21 günlük tohumlama ve gebelik oranı
BREDSUM\S      → boğaya göre (by sire)
BREDSUM\A      → tüm boğalar (AI + doğal)
```

**Sonuç kodları (Breeding Result Codes):**
| Kod | Anlamı |
|-----|--------|
| P | Pregnant (Gebe) |
| O | Open (Boş) |
| R | Rebred (tekrar tohumlanmış) |
| C | Post-conception breeding |
| E | Estimated (doğal aşımda tahmini) |

**BREDSUM kolonları:**
- `%Conc` = Conception risk (bilinen sonuçlardan)
- `#Preg` = Gebe sayısı
- `#Open` = Boş sayısı
- `Other` = Bilinmeyen sonuçlar + 2-gün repeat
- `Abort` = Abort sayısı
- `Total` = Toplam tohumlama
- `SPC` = Services Per Conception (1/CR)

### BREDSUM\E — 21 Günlük Oran

En kritik komut:

- **Insemination Rate (IR):** Her 21 günlük pencerede, eligible ineklerden kaçı tohumlandı? → **düne kadar** hesaplanır
- **Pregnancy Rate (PR):** 21 günlük pencerede kaç gebelik oluştu? → **42 gün öncesine kadar** hesaplanır
- **Son 2 cycle (42 gün) yıllık ortalamaya DAHİL EDİLMEZ** — çünkü sonucu bilinmeyen tohumlamalar olabilir
- **CR ≈ #Preg / (Total - Other)** — yaklaşık hesaplanabilir

### 21-Day Cycle Logic

```
                  VWP (50-60 gün)
Buzağılama ──────────────────────► Eligible başlar
                                       │
     ┌─────────────────────────────────┤
     │  21 gün     21 gün     21 gün   │
     │  cycle 1    cycle 2    cycle 3  │
     │  ├─ breed?  ├─ breed?  ├─ preg  │
     ▼  ▼          ▼                   
```

**Kurallar:**
- Her hayvan 21 günlük pencerede **sadece 1 kez** eligible sayılır (ilk tohumlama sonrası gebe kalana kadar eligible kalmaya devam eder AMA aynı pencerede bir daha sayılmaz)
- Gebe kalan hayvan sonraki pencerelerde eligible DEĞİLDİR
- Düve ve inekler **ayrı** hesaplanır (`BREDSUM` vs `BREDSUM\Y`)

---

## Endüstri Standart Formüller

### Pregnancy Rate (PR)
```
PR = # Pregnant in 21-day window / # Eligible cows in that window
PR = HDR × CR
```

### Conception Rate (CR)
```
CR = # Pregnant / # Bred (with known outcomes)
CR = %Conc in BREDSUM
```

### 21-Day Pregnancy Rate
```
21-Day PR = (Pregnancies confirmed in 21-day interval) / (Cows eligible at start of interval)
Son 42 gün hariç — güvenilir veri için
```

### Heat Detection Rate (HDR) = Insemination Rate
```
HDR = # Inseminated in 21 days / # Eligible in 21 days
```

### Services Per Conception (SPC)
```
SPC = Total Services / Total Pregnancies
SPC = 1 / CR
```

---

## Projemiz İçin Uyarlanabilir Kurallar

### Hemen Uygulanabilir (Mevcut altyapı ile)

```sql
-- 1. CR (Gebelik Başarı Oranı) — ZATEN VAR
SELECT 
  COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))::float / 
  COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı','Boş'))::float * 100 AS cr
FROM tohumlama;

-- 2. 21-Gün PR için Eligible View'u
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
    AND d.tarih < CURRENT_DATE - 50  -- VWP
  );
```

### Sonraki Faz (Dashboard Geliştirme)

3. **21-günlük trend grafiği** — BREDSUM\E benzeri, 21'er günlük dilimlerde PR
4. **Heat Detection Rate** — eligible hayvanların kaçı tohumlanmış?
5. **Days to First Service** — buzağılama → ilk tohumlama ortalaması
6. **Calving Interval** — iki doğum arası gün (mevcut `dogum` tablosu ile)
