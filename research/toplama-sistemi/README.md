# 100.000 TL AM5 Yazılım + AI İş İstasyonu — Araştırma Raporu

**Tarih:** 23 Mayıs 2026 (Güncelleme: Paradigma Değişikliği)
**Kullanım:** Yazılım geliştirme + API tabanlı AI/Multi-Agent + Docker/mikroservis
**Durum:** Sıfırdan kurulum (monitör, koltuk, UPS, klavye/mouse dahil)
**Kaynak:** `00-kaynak/toplama-sistem.md` ön araştırması + canlı fiyat doğrulama + `00-kaynak/sinerji-oem-raw-data.txt` ham veri

> ## ⚡ Paradigma Değişikliği (23 Mayıs 2026)
> 
> **Eski hedef:** Lokal LLM çalıştırmak için VRAM biriktir, GPU'ya yatırım yap.
> **Yeni hedef:** API tabanlı otonom Multi-Agent, paralel süreçler, Docker ve mikroservisler için saf işlemci/okuma-yazma gücüne odaklan.
> 
> *"Ekran kartı yarı yolda bırakmasın yeter"* — VRAM'a para vermek yerine parayı CPU'ya yatır.
> 
> **★ Yeni öneri:** `01-setup-detay/setup-api-multi-agent.md` — Ryzen 9 9900X (12C/24T) + RTX 4060 Ti 8GB + KC3000 DRAM SSD = ~96.646-100.945 TL (100-105K bant)

---

## Piyasa Durumu (Güncel)

### Kritik Tespitler

**1. RAM Fiyat Anomalisi (En Önemli Bulgu)**
6000MHz CL30 32GB DDR5 kitler hâlâ ~30.000 TL seviyesinde. Perakende parça toplamayı ekonomik olarak çökerten temel sebep bu. Çözüm: OEM (hazır sistem) almak veya 6400MHz CL32 RAM kullanmak (~6.318 TL).

**2. RTX 5070 vs 4070 Super Fiyat Kıyımı**
RTX 5070 (35.243 TL) selefi RTX 4070 Super'den (38.128 TL) daha ucuz. 40 serisi stok eritme indirimi yapılmadıkça alınmaz.

**3. OEM Sübvansiyon Paradoksu**
Sinerji Tavsiye Sistem RTX 5070 (~46.242 TL) içinde: Ryzen 5 7500F + RTX 5070 + 16GB DDR5 + 500GB SSD + kasa + PSU. Aynı parçaları perakende alsan ~80.000 TL'yi bulur. OEM almak çok daha mantıklı.

**4. RAM Keşfi: 6400MHz CL32 Alternatifi**
6000MHz CL30 32GB = ~30.000 TL iken, 6400MHz CL32 32GB = ~6.318 TL. Zen 4'te 2:1 modda çalışsa da performans kaybı %1-2 — 24.000 TL farka kesinlikle değmez.

### Doğrulanan Fiyatlar

| Parça | Ön Araştırma | Güncel (22 Mayıs) | Kaynak |
|-------|-------------|-------------------|--------|
| Ryzen 5 7600 MPK | 7.313 TL | **7.313 TL** ✅ | Cimri/PttAVM |
| Ryzen 5 7500F Tray | - | **5.990 TL** | Epey |
| Ryzen 5 7600 Tray | 7.490 TL | **7.441 TL** ⬇️ | Epey |
| Ryzen 7 7700 Tray | 9.707 TL | **9.707 TL** ✅ | Epey |
| PNY RTX 5070 Triple Fan 12GB | 35.243 TL | **35.243 TL** ✅ | Cimri/idefix |
| Asus Prime RTX 5070 OC 12GB | 35.899 TL | **35.462 TL** ⬇️ | Cimri/PttAVM |
| Asus Dual RTX 5060 Ti 16GB | 29.419 TL | **29.419 TL** ✅ | Cimri |
| Thermalright PS 120 SE | 2.215 TL | **1.999 TL** ⬇️ | Gaming.Gen.TR |
| Gigabyte B650 Eagle AX WiFi | - | **6.995 TL** | Cimri |
| MSI PRO B650M-B DDR5 | - | **4.139 TL** | Cimri |
| Asus TUF B650-E WiFi | 9.509 TL | **7.849 TL** ⬇️ | Epey |
| Kingston NV3 2TB | 10.999 TL | **10.999 TL** ✅ | Akakçe |
| Kingston KC3000 2TB (DRAM) | 16.474 TL | **16.474 TL** ✅ | Akakçe |
| MSI MAG A750GL Gen5.1 750W | 5.143 TL | **5.143 TL** ✅ | Akakçe |
| MSI MAG A850GL Gen5 850W | 6.399 TL | **6.399 TL** ✅ | Akakçe |
| BitFenix Enso Mesh | 2.726 TL | **2.726 TL** ✅ | Akakçe |
| Philips Evnia 27" 2K 260Hz | 10.599 TL | **10.599 TL** ✅ | Cimri |
| Fazeon 27" 2K 150Hz | 6.650 TL | **6.650 TL** ✅ | Akakçe |
| Tunçmatik Lift 1500VA | 5.717 TL | **5.717 TL** ✅ | Akakçe |
| Seduna Thunder Pro | 5.599 TL | **5.599 TL** ✅ | Akakçe |
| Seduna Maxim UP | 5.199 TL | **5.199 TL** ✅ | Akakçe |
| Logitech MX Keys Mini Combo | 8.279 TL | **8.279 TL** ✅ | Akakçe |
| Logitech MK295 Silent Set | 1.255 TL | **1.255 TL** ✅ | Akakçe |

✅ = Fiyat sabit / doğrulandı
⬇️ = Fiyat düştü

---

## Setup Karşılaştırması (Hızlı Bakış)

| Kriter | **★★ Setup 0 API** | ★ Setup 1 OEM | Setup 2 Custom | Setup 3 AI | **🆕 Setup 6 AMD** | **🆕 Setup 7 2. El** |
|--------|-------------------|---------------|----------------|------------|-------------------|-----------------|
| **Toplam** | **~96.646-100.945** | **~90.000 TL** | **~96.500 TL** | **~93.700 TL** | **~90.047 TL** | **~86.492 TL** |
| **CPU** | **R9 9900X 12C/24T** 🏆 | R5 7500F 6C | R5 7600 6C | R5 7600 6C | R5 7600 6C | R5 7600 6C |
| **GPU** | RTX 4060 Ti 8GB | RTX 5070 12GB | RTX 5070 12GB | RTX 5060 Ti 16GB | RX 9070 XT 16GB | RTX 3090 24GB |
| **VRAM** | 8GB | 12GB | 12GB | **16GB** | 16GB | **24GB** 🏆 |
| **RAM** | **32GB 6400MHz** | 16GB OEM | 32GB 6400MHz | 32GB 6400MHz | 32GB 6400MHz | 32GB 6400MHz |
| **SSD** | **KC3000 DRAM** 🏆 | NV3 2TB | NV3 2TB | NV3 2TB | NV3 2TB | NV3 2TB |
| **Monitör** | Fazeon 27" 150Hz | Philips 260Hz | Fazeon 150Hz | Philips 260Hz | Philips 260Hz | Fazeon 150Hz |
| **Koltuk+KM** | Maxim UP + MK295 | Thunder+MX Keys | Maxim+MK295 | Maxim+MK295 | Maxim+MK295 | Maxim+MK295 |
| **Bütçe** | **100-105K bant** | ~10K fazla | ~3.5K fazla | ~6.3K fazla | ~10K fazla | **~13.5K fazla** |

---

## Önemli Eklemeler (22 Mayıs 2026 Güncellemesi)

### 🆕 Ryzen 9000 Serisi (Zen 5)

Ryzen 9000 serisi orijinal araştırmada yoktu. Mayıs 2026 itibarıyla AM5 platformunun asıl upgrade yolu:

| CPU | Çekirdek | TDP | Fiyat (TL) | Ryzen 7000 Dengi |
|-----|----------|-----|-----------|-----------------|
| Ryzen 5 9600X | 6C/12T | 65W | ~8.641-8.881 | R5 7600 (~7.313 TL) |
| Ryzen 7 9700X | 8C/16T | 65W | ~12.999-14.669 | R7 7700 (~9.707 TL) |
| Ryzen 7 9800X3D | 8C/16T | 120W | ~22.016 | R7 7800X3D (~18.000 TL) |

> **Öneri:** Ryzen 5 7600 ile başla, 2-3 yıl sonra Ryzen 9000 serisine yükselt. AM5 platform ömrü 2027+.

### 🆕 AMD GPU Alternatifi

RX 9070 XT 16GB (~32.000-34.000 TL), RTX 5060 Ti 16GB'a (~29.419 TL) güçlü bir alternatif:
- **256-bit** bellek yolu vs **128-bit** (2× bant genişliği)
- RTX 5070 seviyesinde raster performans
- ROCm ile AI çalıştırma potansiyeli
- Detay: `01-setup-detay/setup-4-amd-rx9070xt.md`

### ⚠️ OEM Sistem Stoğu ve Fiyat Değişimi

Orijinal araştırmada Sinerji OEM RTX 5070 sistemi ~46.242 TL olarak hesaplanmıştı. 
Güncel web sorgusunda Sinerji'de RTX 5070 OEM paketlerin **61.999 TL'den başladığı** görülüyor.
Bu, araştırmanın temel varsayımını değiştirebilir:

- Eski fiyat (~46.242 TL) ile: Toplam ~89.434 TL (bütçe içinde)
- Yeni fiyat (~61.999 TL) ile: Toplam ~105.191 TL (bütçeyi aşıyor)

> **Öneri:** Satın almadan önce Sinerji'den güncel fiyat teyit edilmeli.
> Fiyat artmışsa Setup 2 (Custom RTX 5070) veya Setup 7 (2. El RTX 3090) alternatif olarak değerlendirilmeli.

### 🆕 İkinci El GPU — En Yüksek VRAM

RTX 3090 24GB (2. el ~25.000-30.000 TL) bu bütçede en yüksek VRAM seçeneği:
- 30B-34B modeller sorunsuz çalışır
- Bütçede ~13.000 TL fazla kalır
- Risk: mining kartı, garanti yok
- Detay: `01-setup-detay/setup-5-ikinci-el-rtx3090.md`

---

## Nihai Öneri (Güncellenmiş)

**★★ Setup 0** (API+Multi-Agent) — yeni birincil öneri:
- ~96.646-100.945 TL (100-105K bantta esneme kabul edilebilir)
- **Ryzen 9 9900X 12C/24T** — 24 thread ile paralel agent'larda rakipsiz
- RTX 4060 Ti 8GB — "yarı yolda bırakmayan" kart
- KC3000 DRAM'li SSD — sıfır I/O darboğazı
- Detay: `01-setup-detay/setup-api-multi-agent.md`

**★ Setup 1** (OEM RTX 5070) — eski öneri (hâlâ geçerli alternatif):
- ~90.000 TL, bütçede ~10.000 TL tampon
- OEM sübvansiyonu sayesinde en iyi f/p

**Setup 7** (2. El RTX 3090) — lokal LLM hedefse en iyi VRAM/bütçe:
- **24GB VRAM** — bu bütçede rakipsiz
- 30B+ modeller lokal çalışır
- ~86.500 TL — en ucuz setup, ~13.500 TL bütçe fazlası
- Risk: 2. el alım deneyimi gerektirir

Detaylı setup dökümleri için:
- `01-setup-detay/setup-1-oem-rtx5070.md` — ★ ÖNERİLEN: OEM RTX 5070 + tam ekosistem
- `01-setup-detay/setup-2-custom-32gb.md` — Custom RTX 5070 + 32GB RAM
- `01-setup-detay/setup-3-ai-16gb-vram.md` — AI odaklı 16GB VRAM + lokal LLM
- `01-setup-detay/setup-4-amd-rx9070xt.md` — 🆕 AMD RX 9070 XT 16GB VRAM + ROCm
- `01-setup-detay/setup-5-ikinci-el-rtx3090.md` — 🆕 2. El RTX 3090 24GB VRAM
- `02-karsilastirma/karsilastirma.md` — AMD içi 3 setup karşılaştırması
- `02-karsilastirma/intel/` — Intel platform setup'ları ve fiyatlar
- `02-karsilastirma/nihai-karsilastirma.md` — ★ Nihai: 7 setup karşılaştırması + karar akışı
