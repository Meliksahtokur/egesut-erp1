# Setup 3: AI Odaklı 16GB VRAM — Lokal LLM İstasyonu

**Strateji:** Maksimum VRAM (16GB) ile lokal AI/LLM çalıştırmaya hazır sistem
**Toplam:** ~93.700 TL
**Kalan Bütçe:** ~6.300 TL
**Kullanım:** AI/LLM çıkarımı/eğitimi, lokal agent (gelecek), yazılım geliştirme

---

## Parça Listesi

| # | Bileşen | Model | Fiyat (TL) | Satın Alma |
|---|---------|-------|-----------|------------|
| 1 | **CPU** | AMD Ryzen 5 7600 (MPK) 6C/12T | 7.313 | [Cimri/PttAVM](https://www.epey.com/islemci/) |
| 2 | **Anakart** | Gigabyte B650 Eagle AX WiFi 6E | 6.995 | [Cimri](https://www.cimri.com/b650-anakart) |
| 3 | **GPU** | Asus Dual GeForce RTX 5060 Ti OC 16GB GDDR7 | 29.419 | [Cimri](https://www.cimri.com/ekran-kartlari/rtx-5060-ti) |
| 4 | **RAM** | Kingston 32GB (2x16) DDR5 6400MHz CL32 | ~6.318 | [Akakçe](https://www.akakce.com/ram/32-gb-ram.html) |
| 5 | **SSD** | Kingston NV3 2TB PCIe 4.0 NVMe | 10.999 | [Akakçe](https://www.akakce.com/ssd/en-ucuz-kingston-nv3-snv3s-2000g-pci-express-4-0-2-tb-m-2-fiyati,734994021.html) |
| 6 | **PSU** | MSI MAG A750GL Gen5.1 750W 80+ Gold | 5.143 | [Akakçe](https://www.akakce.com/power-supply/en-ucuz-msi-mag-a750gl-750-w-80-plus-gold-tam-moduler-fiyati,122221010.html) |
| 7 | **Kasa** | BitFenix Enso Mesh ARGB E-ATX | 2.726 | [Akakçe](https://www.akakce.com/bilgisayar-kasasi/en-ucuz-bitfenix-enso-mesh-tempered-glass-argb-usb-3-0-atx-mid-tower-kasa-fiyati,1543638604.html) |
| 8 | **CPU Soğutucu** | Thermalright Phantom Spirit 120 SE | 1.999 | [Gaming.Gen.TR](https://www.gaming.gen.tr) |
| 9 | **Monitör** | Philips Evnia 27M2N3501PA 27" 2K IPS 260Hz | 10.599 | [Cimri](https://www.cimri.com/monitor/en-ucuz-philips-evnia-27m2n3501pa00-27-inc-260hz-0-3ms-2k-monitor-fiyatlari,2505714026) |
| 10 | **UPS** | Tunçmatik Lift 1500VA Line-Interactive | 5.717 | [Akakçe](https://www.akakce.com/kesintisiz-guc-kaynagi/) |
| 11 | **Koltuk** | Seduna Maxim UP Çalışma Koltuğu | 5.199 | [Akakçe](https://www.akakce.com/seduna.html) |
| 12 | **Klavye+Mouse** | Logitech MK295 Silent Kablosuz Set | 1.255 | [Akakçe](https://www.akakce.com/klavye-mouse-seti.html) |
| | | **TOPLAM** | **~93.682 TL** | |

---

## VRAM Karşılaştırması: Hangi Modeller Çalışır?

| Model Boyutu | Quantization | RTX 5070 (12GB) | RTX 5060 Ti (16GB) |
|-------------|-------------|-----------------|-------------------|
| 7B (Mistral/Llama 3) | 4-bit | ✅ Çalışır | ✅ Çalışır |
| 13B (Llama 2) | 4-bit | ❌ Taşmaz | ✅ Çalışır |
| 30B (Yi/Zephyr) | 4-bit | ❌ Taşmaz | ⚠️ Sınırda çalışır |
| 70B (Llama 3) | 4-bit | ❌ | ❌ (32GB gerek) |

**RTX 5060 Ti 16GB** ile 13B-30B quantized modelleri lokal çalıştırabilirsin.
RTX 5070 12GB ile maksimum 7B modeller kalır.

> **Not:** Şu an API kullanıyorsun, ileride lokal agent düşünüyorsan 16GB VRAM avantajlı. Ama 30B+ modeller için yine de yetmez — o seviye için 24GB+ (RTX 5090 veya 2. el RTX 3090/4090) gerek.

---

## Bütçe Fazlası (~6.318 TL) ile Yapılabilecekler

- **Koltuk yükseltme:** Seduna Thunder Pro (~5.599 TL) → 719 TL kalır
- **KM yükseltme:** Logitech MX Keys Mini Combo (~8.279 TL) → 2k TL ek gerek
- **2. SSD:** 1TB NVMe daha (~5.000 TL) → 1.318 TL kalır
- **Windows Lisansı** (gerekirse)

---

## Artılar

- 16GB VRAM ile lokal LLM çalıştırmaya hazır
- 6400MHz CL32 RAM ile bütçede rahat
- 260Hz monitör + UPS dahil
- B650 anakart ile Ryzen 9000 yükseltme yolu açık
- Tam kontrol — her parçayı sen seçiyorsun

## Eksiler

- RTX 5060 Ti 128-bit veri yolu → AI iş yüklerinde bant genişliği sınırı
- Oyun performansı RTX 5070'den belirgin düşük
- 16GB VRAM oyunlarda tam kullanılmaz (pazarlama taktiği)
- Custom build = kendin kuracaksın
- 30B+ modeller için yine yetersiz

## Kimler İçin?

- **AI/LLM araştırmacısı** (birincil hedef — 13B-30B modeller)
- **Lokal agent** çalıştırmayı planlayan (gelecekte)
- **Stable Diffusion / görüntü üretimi** yapacak
- Oyun ikincil öncelik

---

## Alternatif: RTX 4060 Ti 16GB ile Daha Ucuz AI

RTX 5060 Ti 16GB (29.419 TL) yerine RTX 4060 Ti 16GB (23.500 TL) kullanılırsa:
- ~5.900 TL tasarruf
- Aynı 16GB VRAM, ama GDDR6 (daha yavaş) ve eski mimari
- AI çıkarımda %10-15 daha yavaş
- Oyunlarda belirgin fark

---

## Güncel Fiyat Linkleri

| Bileşen | En Ucuz Link |
|---------|-------------|
| AMD İşlemciler | https://www.epey.com/islemci/ |
| RTX 5060 Ti | https://www.cimri.com/ekran-kartlari/rtx-5060-ti |
| B650 Anakart | https://www.cimri.com/b650-anakart |
| 32GB DDR5 RAM | https://www.akakce.com/ram/32-gb-ram.html |
| 2TB NVMe SSD | https://www.akakce.com/ssd/2-tb.html |
| PSU | https://www.akakce.com/power-supply/ |
| Kasa | https://www.akakce.com/bilgisayar-kasasi/ |
| 2K Monitör | https://www.akakce.com/monitor/2k-monitor.html |
| UPS 1500VA | https://www.akakce.com/kesintisiz-guc-kaynagi/ |
