# Üreme İstatistikleri — Dış Kaynak Araştırması Sentez Raporu

**Tarih:** 2026-05-31
**Araştırma Kapsamı:** Açık kaynak repo'lar, ticari sistemler (BoviSync/VAS), akademik KPI metodolojisi, frontend mimari referansları
**Sonuç:** Algoritmamız sektör standardında. Temel eksik: VWP, 21-gün PR, eligible tanımı.

---

## 1. Yönetici Özeti

| Konu | Bulgu |
|------|-------|
| **Açık kaynak repro dashboard** | YOK. Tüm sistemler ticari (VAS, BoviSync, DairyComp) |
| **En iyi veri modeli referansı** | farmOS (Asset+Log event-sourcing) — bizim mimarimizle uyumlu |
| **Sektör standardı formüller** | PR = Gebe/Eligible, CR = Gebe/Tohumlanan, 21-gün pencereleri |
| **Eligible tanımı** | VWP (50-60 gün) + gebe değil + aktif |
| **Bizim durumumuz** | `v_ureme_dongusu` + `stat_suru_ozet` açık kaynakta bulunan her şeyden daha sofistike |

---

## 2. KPI Formülleri — Sektör Standardı

### Temel Metrikler

```
Conception Rate (CR)  = Pregnant / Bred × 100
Heat Detection (HDR)  = Inseminated / Eligible × 100
Pregnancy Rate (PR)   = Pregnant / Eligible × 100
PR                    = HDR × CR
Services per Conc.    = 1 / CR
```

### 21-Day Pregnancy Rate (En Kritik)

```
21-Day PR = (21 günlük penceredeki gebelik) / (Pencere başındaki eligible)
```

- Her 21 günde bir hesaplanır (bir kızgınlık döngüsü)
- **Son 42 gün (2 cycle) hariç tutulur** — sonuçlanmamış tohumlamalar güvenilir değil
- DairyComp 305 `BREDSUM\E` komutu bu metriği üretir

### Eligible (Uygun) Hayvan Tanımı

| Kriter | Değer |
|--------|-------|
| Cinsiyet | Dişi |
| Durum | Aktif |
| VWP | Doğumdan sonra ≥50-60 gün |
| Gebelik | Gebe DEĞİL |
| Kuru dönem | Tartışmalı (bazı sistemler dahil eder) |

---

## 3. Bizim Sistem vs Sektör Standardı

| Metrik | Bizde Var mı? | Sektör Standardı |
|--------|-------------|-----------------|
| **CR (Gebelik Başarı)** | ✅ Cycle bazlı %74.7 | Tohumlama bazlı (daha basit) |
| **Repeat breeding** | ✅ `deneme_no` ile cycle tespiti | ✅ Aynı mantık |
| **Bekliyor filtreleme** | ✅ Manuel işaretleme | Otomatik 35-42 gün |
| **Sperma attribution** | ✅ `gebe_sperma` / `son_sperma` | ✅ Aynı |
| **İnek/Düve ayrımı** | ✅ Grup bazlı + doğum kontrolü | ✅ Aynı (BREDSUM vs BREDSUM\Y) |
| **VWP filtresi** | ❌ YOK | ✅ 50-60 gün |
| **21-Gün PR** | ❌ YOK | ✅ Standart |
| **Eligible havuzu** | ❌ YOK | ✅ |
| **Days Open** | ❌ YOK | ✅ |
| **Calving Interval** | ❌ YOK | ✅ |

---

## 4. Veri Modeli: farmOS vs Biz

| farmOS | Bizim Karşılığımız |
|--------|-------------------|
| Asset (Animal) | `hayvanlar` tablosu |
| Log (Insemination) | `tohumlama` tablosu |
| Log (Birth) | `dogum` tablosu |
| Log (Medical) | `islem_log` (asi, tedavi) |
| Group Asset (Herd) | `grup` / `padok` |
| Movement Log | `padok_degistir` RPC |
| Computed geometry | `v_ureme_dongusu` view |

**Sonuç:** Mimari felsefemiz farmOS ile birebir örtüşüyor. Hatta cycle tespiti ve repeat breeding handling ile farmOS'tan daha ilerideyiz.

---

## 5. Öncelikli Aksiyon Planı

| # | Eylem | Zorluk | Kaynak Dosya |
|---|-------|--------|-------------|
| 1 | **VWP filtresi ekle** — `v_ureme_dongusu`'na `dogum` join'i ile | Orta | `04-bovisync-vas.md` |
| 2 | **Eligible view'u oluştur** — VWP + gebe olmayan + aktif | Orta | `03-kulkarni-kpi.md` |
| 3 | **21-Gün PR RPC'si yaz** — BREDSUM\E benzeri | Zor | `04-bovisync-vas.md` |
| 4 | **Days Open metriği** — buzağılama → gebelik gün | Kolay | Mevcut `dogum` + `tohumlama` |
| 5 | **Sperma Top N limit artır** — 5 yerine hepsini göster | Kolay | `stat_suru_ozet_v2.sql` |
| 6 | **Dashboard'a eligible sayısı ekle** | Kolay | `js/ui.js` |

---

## 6. Bireysel Rapor Dosyaları

```
research/ureme-istatistik-repo-arastirmasi/
├── 00-sentez.md              ← bu dosya
├── 01-farmos.md              ← farmOS veri modeli analizi
├── 02-mern-dairytrack.md     ← Frontend mimari referansları
├── 03-kulkarni-kpi.md        ← Akademik KPI metodolojisi + PostgreSQL WHERE clauses
├── 04-bovisync-vas.md        ← BoviSync API + VAS/DairyComp 305 + formüller
└── 05-web-kesif.md           ← Ek keşif (GitHub, akademik, hidden gems)
```

---

## 7. Sonuç

**Açık kaynak dünyasında bizim sistemimizden daha iyi bir repro analitiği YOK.**

İncelenen tüm repo'lar (farmOS, MERN-dairy, dairyTrack, Kulkarni) ya çok basit (CRUD) ya da repro analitiği içermiyor. Ticari sistemler (BoviSync, VAS/DairyComp 305) kapalı kaynak ama dokümantasyonlarından eligible tanımı, 21-gün mantığı ve PR/CR/HDR formülleri çıkarılabiliyor.

Bizim `v_ureme_dongusu` view'ımız, cycle tespiti (`deneme_no`), repeat breeding handling (`bool_or` öncelik sırası), ve sperma attribution modeli (`COALESCE(gebe_sperma, son_sperma)`) ile sektör standardının üzerinde. Tek eksiğimiz: VWP, eligible tanımı, ve 21-günlük PR trendi. Bunlar mevcut altyapıya ek view/RPC olarak entegre edilebilir.
