# Nihai Karşılaştırma Raporu — AMD vs Intel

> ## ⚡ Paradigma Değişikliği (23 Mayıs 2026)
> **Eski hedef:** Lokal LLM çalıştırmak için VRAM biriktir, GPU'ya yatırım yap.
> **Yeni hedef:** API tabanlı otonom Multi-Agent, paralel süreçler, Docker ve mikroservisler için saf işlemci/okuma-yazma gücüne odaklan.
> *"Ekran kartı yarı yolda bırakmasın yeter"* — VRAM'a para vermek yerine parayı CPU'ya yatır.
> **★ Yeni öneri:** [Setup 0](../01-setup-detay/setup-api-multi-agent.md) — Ryzen 9 9900X (12C/24T) + RTX 4060 Ti 8GB + KC3000 = ~96.646-100.945 TL (100-105K bant)

**100.000 TL Bütçe — Yazılım Geliştirme + AI (API tabanlı)**
**Tarih:** 23 Mayıs 2026 (Güncelleme: Paradigma Değişikliği)
**Durum:** Sıfırdan kurulum (monitör, koltuk, UPS, klavye/mouse dahil)

---

## Hızlı Özet

| # | Setup | Platform | Maliyet | Kalan | GPU | CPU | RAM | 
|---|-------|----------|---------|-------|-----|-----|-----|
| **★ 0** | **API+Agent (YENİ)** | **AMD AM5** | **~96.646-100.945 TL** | **100-105K bant** | RTX 4060 Ti 8GB | **R9 9900X 12C/24T 🏆** | 32GB |
| 1 | OEM RTX 5070 | AMD AM5 | ~89.434 TL | 10.566 TL | RTX 5070 12GB | R5 7500F 6C | 16GB |
| 2 | Custom RTX 5070 | AMD AM5 | ~96.427 TL | 3.573 TL | RTX 5070 12GB | R5 7600 6C | 32GB |
| 3 | AI 16GB VRAM | AMD AM5 | ~93.682 TL | 6.318 TL | RTX 5060 Ti 16GB | R5 7600 6C | 32GB |
| 4 | Intel DDR4 Bütçe | Intel LGA1700 | ~88.444 TL | 11.556 TL | RTX 5070 12GB | i5-14400F 10C | 32GB DDR4 |
| 5 | Arrow Lake | Intel LGA1851 | ~97.510 TL | 2.490 TL | RTX 5070 12GB | U5 245KF 14C | 32GB |
| 6 | AMD RX 9070 XT | AMD AM5 | ~90.047 TL | 9.953 TL | RX 9070 XT 16GB | R5 7600 6C | 32GB |
| 7 | 2. El RTX 3090 | AMD AM5 | ~86.492 TL | 13.508 TL | RTX 3090 24GB | R5 7600 6C | 32GB |
✅ = Doğrulanmış fiyat

---

## Platform Karşılaştırması

| Kriter | AMD AM5 (Zen 4/Zen 5) | Intel LGA1700 (14. nesil) | Intel LGA1851 (Arrow Lake) |
|--------|----------------------|--------------------------|---------------------------|
| **Soket Ömrü** | 2027+ 🏆 | Ölü ☠️ | ~2-3 yıl |
| **CPU+Board+RAM (giriş)** | ~21.229 TL ✅ | ~13.267 TL ✅ | ~23.988 TL ✅ |
| **CPU+Board+RAM (orta)** | ~24.824 TL ✅ | ~19.500 TL | ~28.000 TL |
| **Ryzen 9000 Uyumu** | ✅ (BIOS update) | ❌ | ❌ |
| **DDR4 Desteği** | ❌ | ✅ (B760 ile) | ❌ |
| **QuickSync** | ❌ | ✅ (non-F CPU) | ✅ (285K ile) |
| **PCIe 5.0** | ✅ (B650/E) | ❌ (B760) | ✅ (B860/Z890) |
| **WiFi** | WiFi 6/6E | WiFi 6/6E | WiFi 6E/7 |
| **En Verimli CPU** | 65W 🏆 | 65W | 125W |
| **Fiyat/Performans** | 🏆 | ⚠️ | ❌ |

---

## 5 Setup'un Detaylı Karşılaştırması

### ★ Setup 1: OEM RTX 5070 — AMD AM5 (ÖNERİLEN)

**Maliyet:** ~89.434 TL | **Kalan:** 10.566 TL
**Strateji:** OEM hazır sistem + ek depolama + soğutucu + ekosistem
**GPU:** RTX 5070 12GB (192-bit, en iyi f/p)
**RAM:** 16GB DDR5 (OEM, sonra yükselt)
**Platform:** AM5 (Ryzen 5 7500F, B840 anakart)
**Monitör:** Philips Evnia 27" 260Hz
**Koltuk+KM:** Seduna Thunder Pro + MX Keys Mini Combo
**UPS:** Tunçmatik Lift 1500VA

**Artılar:** En iyi fiyat/performans, OEM sübvansiyonu, bütçede rahat, ekosistem dahil
**Eksiler:** 16GB RAM başlangıç, B840 anakart (B650'den zayıf)

### Setup 2: Custom RTX 5070 — AMD AM5

**Maliyet:** ~96.427 TL | **Kalan:** 3.573 TL
**Strateji:** Parça parça toplama, tam kontrol
**GPU:** RTX 5070 12GB
**RAM:** 32GB DDR5 6400MHz CL32
**Platform:** AM5 (Ryzen 5 7600, Asus TUF B650-E WiFi)
**Monitör:** Fazeon 27" 150Hz

**Artılar:** 32GB RAM, B650 anakart, Ryzen 9000 hazır
**Eksiler:** 7k TL daha pahalı, daha ucuz monitör/koltuk/KM

### Setup 3: AI 16GB VRAM — AMD AM5

**Maliyet:** ~93.682 TL | **Kalan:** 6.318 TL
**Strateji:** Maksimum VRAM, lokal LLM için
**GPU:** RTX 5060 Ti 16GB (128-bit)
**RAM:** 32GB DDR5 6400MHz CL32
**Platform:** AM5 (Ryzen 5 7600, Gigabyte B650 Eagle AX WiFi)
**Monitör:** Philips Evnia 27" 260Hz

**Artılar:** 16GB VRAM (13B-30B LLM çalışır), 260Hz monitör
**Eksiler:** 128-bit veri yolu, oyun performansı düşük

### Setup 4: Intel LGA1700 DDR4 Bütçe ✅

**Maliyet:** ~88.444 TL | **Kalan:** 11.556 TL
**Strateji:** Dead socket avantajı + DDR4 ucuzluğu
**GPU:** RTX 5070 12GB
**RAM:** 32GB DDR4 3200MHz CL16 (sadece ~3.500 TL!)
**Platform:** LGA1700 (i5-14400F, B760 DDR4 anakart)
**Monitör:** Fazeon 27" 150Hz

**Artılar:** En ucuz CPU+Board+RAM (14.500 TL), bütçede çok rahat
**Eksiler:** Ölü soket (upgrade yok), DDR4 performans kaybı, Intel fiyatları doğrulanmamış

### Setup 5: Intel Arrow Lake LGA1851 ✅

**Maliyet:** ~97.510 TL | **Kalan:** 2.490 TL
**Strateji:** Yeni nesil Intel, AMD'ye alternatif
**GPU:** RTX 5070 12GB
**RAM:** 32GB DDR5 6400MHz CL32
**Platform:** LGA1851 (Core Ultra 5 245KF, B860 anakart)
**Monitör:** Fazeon 27" 150Hz

**Artılar:** En hızlı tek çekirdek, yeni platform
**Eksiler:** Bütçeyi zorlar, fiyatlar oturmamış, Hyper-Threading yok

### Setup 6: AMD RX 9070 XT — 16GB VRAM + ROCm 🆕

**Maliyet:** ~90.047 TL | **Kalan:** ~9.953 TL
**Strateji:** AMD GPU ile yüksek VRAM, düşük maliyet
**GPU:** RX 9070 XT 16GB (256-bit, ~33.000 TL)
**RAM:** 32GB DDR5 6400MHz CL32
**Platform:** AM5 (Ryzen 5 7600, Gigabyte B650 Eagle AX WiFi)
**Monitör:** Philips Evnia 27" 260Hz

**Artılar:** 256-bit bellek yolu, RTX 5070 seviyesi raster, FSR 4, bütçede rahat
**Eksiler:** ROCm vs CUDA uyum riski, RT'de zayıf, 280W TDP

### Setup 7: 2. El RTX 3090 24GB — Lokal LLM İstasyonu 🆕

**Maliyet:** ~86.492 TL | **Kalan:** ~13.508 TL
**Strateji:** İkinci el GPU ile maksimum VRAM, minimal bütçe
**GPU:** RTX 3090 24GB (2. el, ~28.000 TL)
**RAM:** 32GB DDR5 6400MHz CL32
**Platform:** AM5 (Ryzen 5 7600, MSI PRO B650M-B)
**Monitör:** Fazeon 27" 150Hz

**Artılar:** 🏆 **24GB VRAM** — 30B+ modeller lokal çalışır, en ucuz setup
**Eksiler:** 2. el riski, 350W TDP, DLSS 3 yok, büyük kasa gerek

---

## Karar Matrisi

| Kriter | ★ S1 OEM | S2 Custom | S3 AI 16GB | S4 Intel DDR4 | S5 Arrow Lk | **🆕 S6 AMD GPU** | **🆕 S7 2. El** |
|--------|----------|-----------|------------|---------------|-------------|-------------------|-----------------|
| **Fiyat/Performans** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Platform Ömrü** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Oyun (1440p)** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **AI LLM 13B** | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | **⭐⭐⭐⭐⭐** |
| **AI LLM 30B+** | ❌ | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | **✅** |
| **Yazılım Derleme** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Docker/VM** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Geleceğe Dönük** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Bütçe Dostu** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **VRAM Miktarı** | 12GB | 12GB | 16GB | 12GB | 12GB | 16GB | **24GB 🏆** |
| **Risk** | Düşük | Düşük | Düşük | Düşük | Orta | Orta (ROCm) | **Yüksek** (2. el) |

---

## Nihai Karar Akışı

```
                 ┌──────────────────────────────────────────┐
                 │     100.000 TL — API + Multi-Agent      │
                 └───────────────┬──────────────────────────┘
                                 │
                      ┌──────────┴──────────────────┐
                      ▼                              ▼
             ┌────────────────────┐       ┌─────────────────────┐
             │  Lokal LLM 30B+   │       │ API AI + Multi-Agent│
             │  şart mı?         │       │ (★ varsayılan)      │
             └──────┬────────────┘       └──────────┬──────────┘
                    ▼                               ▼
           ┌──────────────────┐           ┌───────────────────┐
           │ 2. el riski?    │           │ ★ Setup 0         │
           ├──────────────────┤           │ Ryzen 9 9900X     │
           │ EVET → Setup 6  │           │ 12C/24T CPU 🏆    │
           │ AMD RX 9070 XT  │           │ RTX 4060 Ti 8GB   │
           │ 16GB VRAM       │           │ KC3000+32GB       │
           │ 90.047 TL       │           │ 100-105K bant     │
           ├──────────────────┤           └───────────────────┘
           │ HAYIR → ★ S7    │
           │ 2. El 3090 24GB │           Eski alternatifler:
           │ 86.492 TL       │           Setup 1 (OEM 89.434 TL)
           └──────────────────┘           Setup 3 (AI 93.682 TL)
```

---

## Öneri

### ★★ YENİ: Setup 0 (API + Multi-Agent) — Nihai Öneri

> Paradigma değişikliği sonrası yeni birincil öneri.

Multi-Agent, Docker, mikroservis ve API tabanlı AI için tasarlanmış saf işlem gücü istasyonu:
- **~96.646-100.945 TL** — 100-105K TL bantta esneme kabul edilebilir
- **Ryzen 9 9900X 12C/24T** 🏆 — 24 thread ile 6 çekirdekliye göre %100+ daha hızlı
- **RTX 4060 Ti 8GB** — "yarı yolda bırakmayan" kart, 15.000 TL GPU'dan tasarruf
- **KC3000 2TB DRAM'li SSD** — agent logları ve container yazmalarında sıfır darboğaz
- **32GB 6400MHz CL32** — stabil Dual-Channel
- Detay: `01-setup-detay/setup-api-multi-agent.md`

### ★ Setup 1 (AMD AM5 OEM RTX 5070) — Eski Öneri (Hâlâ Geçerli)

Yazılım geliştirme + API ile AI + 1440p oyun için eski ana öneri:
- **89.434 TL** — bütçede 10k TL tampon
- OEM sübvansiyonu sayesinde en iyi f/p
- **⚠ Not:** Paradigma değişikliği sonrası Setup 0 daha iyi bir alternatif sunuyor

### Setup 3 (AMD AM5 16GB VRAM) — AI Ağırlıklı

Eğer lokal LLM/agent birincil hedefse:
- **93.682 TL**
- 16GB VRAM ile 13B-30B quantized modeller çalışır
- 260Hz monitör + UPS dahil
- 6400MHz CL32 RAM ile bütçede rahat

### Setup 4 (Intel LGA1700 DDR4) — Sadece Bütçe Kritikse ✅

- Intel fiyatları doğrulandı — en ucuz CPU+Board+RAM: ~13.267 TL
- Platform ömrü yok (2-3 yıl sonra komple değişim)
- DDR4 32GB 3200 CL16: ~3.027 TL
- i5-14400F tray alınırsa toplam ~85.000 TL'ye kadar düşer

### 🆕 Setup 6 (AMD RX 9070 XT) — ROCm ile AI + Oyun Dengesi

AMD GPU ile NVIDIA fiyatına alternatif:
- **~90.047 TL** — Setup 1'e yakın bütçe
- RX 9070 XT 16GB, 256-bit bellek yolu
- ROCm ekosistemi 2026'da hızla olgunlaşıyor
- FSR 4 desteği, iyi raster performansı
- **Risk:** ROCm hâlâ CUDA kadar olgun değil

### 🆕 Setup 7 (2. El RTX 3090 24GB) — Lokal LLM için En İyi VRAM

Lokal LLM birincil hedefse en mantıklı seçim:
- **~86.492 TL** — en ucuz setup, ~13.500 TL bütçe fazlası
- **24GB VRAM** 🏆 — bu bütçede rakipsiz
- **30B-34B modeller full lokal** (Qwen, Yi, DeepSeek Coder)
- Bütçe fazlası ile 64GB RAM yükseltmesi yapılabilir
- **Risk:** 2. el alım (mining kartı, garanti yok, termal pad aşınması)

---

## Sonraki Adımlar

1. ~~Intel fiyatları doğrulandı — ⚠️ işaretleri kaldırıldı~~ ✅
2. ~~Ryzen 9000 serisi, AMD GPU ve ikinci el RTX 3090 seçenekleri eklendi~~ ✅
3. ~~Paradigma değişikliği: Setup 0 (API+Multi-Agent) eklendi, Ryzen 9 9900X + RTX 4060 Ti~~ ✅
4. OEM (Sinerji) sistem stoğu güncel durumu web'den kontrol edilecek
5. AI yazılım kurulum rehberi ayrı dosyaya taşınacak

---

## Klasör Yapısı

```
research/
└── toplama-sistemi/
    ├── README.md                         (genel bakış + doğrulanmış fiyatlar)
    ├── 00-kaynak/
    │   ├── toplama-sistem.md             (ön araştırma — kaynak)
    │   └── sinerji-oem-raw-data.txt       (Sinerji OEM fiyat ham verisi)
    ├── 01-setup-detay/
    │   ├── setup-1-oem-rtx5070.md        ★ OEM RTX 5070
    │   ├── setup-2-custom-32gb.md          Custom RTX 5070 + 32GB
    │   ├── setup-3-ai-16gb-vram.md         AI 16GB VRAM
    │   ├── setup-4-amd-rx9070xt.md       🆕 AMD RX 9070 XT
    │   └── setup-5-ikinci-el-rtx3090.md  🆕 2. El RTX 3090 24GB
    └── 02-karsilastirma/
        ├── karsilastirma.md                AMD içi karşılaştırma
        ├── nihai-karsilastirma.md        ★ Nihai rapor (bu dosya)
        └── intel/
            ├── intel-setup.md              Intel kombinasyonları
            └── intel-vs-amd.md             Platform karşılaştırması
```
