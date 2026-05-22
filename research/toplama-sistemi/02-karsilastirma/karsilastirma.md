# 3 Setup Karşılaştırması

> 100.000 TL Bütçe — AM5 Platform — Yazılım + AI Kullanımı

---

## Genel Karşılaştırma

| Kriter | Setup 1: OEM 5070 ★ | Setup 2: Custom 5070 | Setup 3: AI 16GB |
|--------|--------------------|--------------------|-----------------|
| **Toplam Maliyet** | **~89.434 TL** | **~96.427 TL** | **~93.682 TL** |
| **Kalan Bütçe** | **~10.566 TL** | **~3.573 TL** | **~6.318 TL** |
| **Kurulum** | OEM (hazır) | Custom (kendin) | Custom (kendin) |
| **Garanti** | OEM tek garanti | Parça parça | Parça parça |

### İşlemci & Anakart

| Kriter | Setup 1 | Setup 2 | Setup 3 |
|--------|---------|---------|---------|
| CPU | Ryzen 5 7500F (6C/12T) | Ryzen 5 7600 (6C/12T) | Ryzen 5 7600 (6C/12T) |
| Anakart | B840 (OEM) | Asus TUF B650-E WiFi | Gigabyte B650 Eagle AX |
| PCIe 5.0 SSD | ❌ (1 tane) | ✅ | ✅ |
| WiFi | OEM'e bağlı | WiFi 6 | WiFi 6E |
| Ryzen 9000 Ready | ⚠️ BIOS'a bağlı | ✅ | ✅ |

### GPU & RAM

| Kriter | Setup 1 | Setup 2 | Setup 3 |
|--------|---------|---------|---------|
| GPU | RTX 5070 12GB GDDR7 | RTX 5070 12GB GDDR7 | RTX 5060 Ti 16GB GDDR7 |
| VRAM | 12GB | 12GB | **16GB** |
| Bellek Yolu | **192-bit** | **192-bit** | 128-bit |
| Bant Genişliği | ~672 GB/s | ~672 GB/s | ~448 GB/s |
| RAM Kapasite | 16GB (OEM) | 32GB | 32GB |
| RAM Hızı | OEM'e bağlı | 6400MHz CL32 | 6400MHz CL32 |

### Depolama & Güç

| Kriter | Setup 1 | Setup 2 | Setup 3 |
|--------|---------|---------|---------|
| SSD (Ana) | 500GB NVMe (OEM) | NV3 2TB | NV3 2TB |
| SSD (Ek) | NV3 2TB | — | — |
| Toplam Depolama | 2.5TB | 2TB | 2TB |
| PSU | OEM PSU | MSI A750GL Gen5.1 | MSI A750GL Gen5.1 |

### Çevre Birimleri

| Kriter | Setup 1 | Setup 2 | Setup 3 |
|--------|---------|---------|---------|
| Monitör | Philips 27" 260Hz | Fazeon 27" 150Hz | Philips 27" 260Hz |
| Koltuk | Seduna Thunder Pro | Seduna Maxim UP | Seduna Maxim UP |
| Klavye+Mouse | MX Keys Mini Combo | MK295 Silent Set | MK295 Silent Set |
| UPS | Tunçmatik 1500VA | Tunçmatik 1500VA | Tunçmatik 1500VA |

---

## Performans Karşılaştırması (Web'den Derlenen Veriler)

> Yıldız puanları yerine gerçek benchmark verileri. Kaynak: TechPowerUp, PassMark, UserBenchmark, NanoReview (Mayıs 2026).

### GPU Performansı (RTX 5070 vs RTX 5060 Ti vs RX 9070 XT)

| Kriter | RTX 5070 (12GB) | RTX 5060 Ti (16GB) | RX 9070 XT (16GB) | RTX 3090 (24GB, 2. el) |
|--------|----------------|-------------------|-------------------|----------------------|
| **1440p Ortalama FPS** | ~112 🏆 | ~76 ⭐⭐⭐ | ~105 🏆 | ~95 ⭐⭐⭐⭐ |
| **1440p RT Açık FPS** | ~67 🏆 | ~42 ⭐⭐ | ~58 ⭐⭐⭐ | ~55 ⭐⭐⭐ |
| **AI LLM 7B (Q4) tok/s** | ~85 🏆 | ~55 ⭐⭐⭐ | ~50 ⭐⭐⭐ | ~70 ⭐⭐⭐⭐ |
| **AI LLM 13B (Q4) tok/s** | ~45 ⭐⭐ | ~30 ⭐⭐ | ~28 ⭐⭐ | **~40 ⭐⭐⭐** |
| **AI LLM 30B (Q4)** | ❌ Taşmaz | ⚠️ Sınırda | ⚠️ Sınırda | **✅ Çalışır** |
| **Stable Diffusion (img/s)** | ~8.5 🏆 | ~5.5 ⭐⭐⭐ | ~5.0 ⭐⭐⭐ | ~7.0 ⭐⭐⭐⭐ |
| **Güç Tüketimi (W)** | ~220W | ~150W 🏆 | ~280W ⚠️ | **~350W** ❌ |
| **Fiyat (TL)** | 35.243 | 29.419 | ~33.000 | ~28.000 (2. el) |

> FPS değerleri 1440p Ultra ayarlar, DLSS/FSR kapalı. Ray Tracing: Cyberpunk 2077'de RT Ultra.
> AI token/s: llama.cpp ile Q4_K_M quantized modellerde ölçülmüştür.

### CPU Performansı (Ryzen 7x00 vs Ryzen 9x00)

| Kriter | R5 7500F | R5 7600 | R5 9600X (Zen 5) |
|--------|----------|---------|-----------------|
| **Cinebench R23 Tek** | ~1.830 | ~1.940 | **~2.230** (+15%) |
| **Cinebench R23 Çok** | ~14.800 | ~15.200 | **~16.900** (+11%) |
| **Blender (dakika)** | ~12.5 | ~12.0 | **~10.8** |
| **Kod Derleme (Linux kernel, sn)** | ~185 | ~178 | **~160** |
| **Fiyat (TL)** | ~5.990 | ~7.313 | ~8.641 |
| **F/P (Cinebench/fiyat)** | **⭐⭐⭐⭐⭐** | ⭐⭐⭐⭐ | ⭐⭐⭐ |

### Opsiyonel: Setup Karşılaştırması (Yıldız Özet)

| Kriter | Setup 1 ★ | Setup 2 | Setup 3 |
|--------|---------|---------|---------|
| **1440p Oyun** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **AI LLM 7B (Q4)** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **AI LLM 13B (Q4)** | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **AI LLM 30B (Q4)** | ❌ | ❌ | ⭐⭐⭐ |
| **Kod Derleme** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Docker/Container** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Multi-task (RAM)** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Fiyat/Performans** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## Hangi Setup Kimin İçin?

| Profil | Öneri | Sebep |
|--------|-------|-------|
| **Yazılım geliştirici** (ana iş) + ara sıra AI | **Setup 1** | En iyi f/p, RTX 5070, ekosistem dahil, bütçede rahat |
| **AI ağırlıklı** + oyun da oynar | **Setup 2** (6400MHz RAM ile) | RTX 5070 + 32GB RAM, custom build tam kontrol |
| **Sadece AI/LLM**, oyun önemli değil | **Setup 3** | 16GB VRAM ile en büyük modeller, iyi monitör |
| **Lokal agent** (gelecek) | **Setup 3** | 16GB VRAM ileride agent için avantajlı |
| **Bütçeyi aşmak istemeyen** | **Setup 1** | 89k TL'de kalıyor, 10k TL tampon var |
| **En iyi monitör + klavye deneyimi** | **Setup 1** | 260Hz + MX Keys, diğerlerinden üstün |
| **Custom build meraklısı** | **Setup 2** | Her parçayı kendin seç, kendin kur |

---

## Maliyet Dağılımı (Setup 1)

```
OEM Sistem        46.242 TL  (52%)
Monitör           10.599 TL  (12%)
SSD NV3 2TB       10.999 TL  (12%)
MX Keys Mini       8.279 TL   (9%)
UPS                5.717 TL   (6%)
Koltuk             5.599 TL   (6%)
CPU Soğutucu       1.999 TL   (2%)
                   ─────────
TOPLAM            89.434 TL
KALAN             10.566 TL
```

## Maliyet Dağılımı (Setup 2)

```
GPU (RTX 5070)    35.243 TL  (37%)
RAM (32GB)         6.318 TL   (7%)
CPU                7.313 TL   (8%)
Anakart            7.849 TL   (8%)
SSD NV3 2TB       10.999 TL  (11%)
PSU                5.143 TL   (5%)
Kasa               2.726 TL   (3%)
Soğutucu           2.215 TL   (2%)
Monitör            6.650 TL   (7%)
UPS                5.717 TL   (6%)
Koltuk             5.199 TL   (5%)
KM                 1.255 TL   (1%)
                   ─────────
TOPLAM            96.427 TL
KALAN              3.573 TL
```

## Maliyet Dağılımı (Setup 3)

```
GPU (5060 Ti 16GB) 29.419 TL  (31%)
RAM (32GB)         6.318 TL   (7%)
CPU                7.313 TL   (8%)
Anakart            6.995 TL   (7%)
SSD NV3 2TB       10.999 TL  (12%)
PSU                5.143 TL   (5%)
Kasa               2.726 TL   (3%)
Soğutucu           1.999 TL   (2%)
Monitör           10.599 TL  (11%)
UPS                5.717 TL   (6%)
Koltuk             5.199 TL   (6%)
KM                 1.255 TL   (1%)
                   ─────────
TOPLAM            93.682 TL
KALAN              6.318 TL
```

---

## Nihai Karar Akışı

```
Soru: Lokal LLM (13B+) çalıştıracak mısın?
├── EVET → Setup 3 (16GB VRAM)
└── HAYIR (API kullanıyorum) → Soru: Custom build mi istiyorsun?
    ├── EVET → Setup 2 (tam kontrol, 32GB RAM)
    └── HAYIR / fark etmez → ★ Setup 1 (en iyi f/p)
```

---

## Intel Tarafı

Intel LGA1700/1851 araştırması bu raporun ikinci fazında yapılacak. İki platform merge edilip nihai karşılaştırma raporu yazılacak.
