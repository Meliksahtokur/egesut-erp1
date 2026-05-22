# Setup 6: AMD RX 9070 XT — 16GB VRAM + ROCm Potansiyeli 🆕

**Strateji:** AMD GPU ile yüksek VRAM + daha düşük maliyet
**Toplam:** ~90.047 TL
**Kalan Bütçe:** ~9.953 TL
**Kullanım:** Yazılım geliştirme + AI/LLM (ROCm) + 1440p oyun

---

## Neden AMD GPU?

Araştırmanın orijinal Setup 3'ü RTX 5060 Ti 16GB (~29.419 TL, 128-bit) öneriyordu. 
AMD RX 9070 XT 16GB (~32.000-34.000 TL) ile karşılaştırma:

| Kriter | RTX 5060 Ti 16GB | RX 9070 XT 16GB | RX 9070 16GB |
|--------|-----------------|-----------------|-------------|
| **Fiyat** | ~29.419 TL | ~32.000-34.000 TL | ~27.000 TL |
| **VRAM** | 16GB GDDR7 | 16GB GDDR6 | 16GB GDDR6 |
| **Bellek Yolu** | **128-bit** (darboğaz) | **256-bit** 🏆 | **256-bit** 🏆 |
| **Bant Genişliği** | ~448 GB/s | ~624 GB/s 🏆 | ~624 GB/s 🏆 |
| **Oyun (raster)** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Ray Tracing** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **AI/ROCm** | CUDA (olgun) ✅ | ROCm (gelişiyor) ⚠️ | ROCm (gelişiyor) ⚠️ |
| **FSR 4** | ❌ | ✅ | ✅ |

**Önemli**: RX 9070 XT, RTX 5060 Ti'dan sadece ~3.000 TL daha pahalı ama:
- **2× bellek yolu** (256-bit vs 128-bit) — AI iş yüklerinde büyük fark
- **%40 daha fazla bant genişliği**
- **Önemli ölçüde daha iyi oyun performansı**

---

## Parça Listesi

| # | Bileşen | Model | Fiyat (TL) | Durum |
|---|---------|-------|-----------|-------|
| 1 | **CPU** | AMD Ryzen 5 7600 (MPK) 6C/12T | 7.313 | ✅ |
| 2 | **Anakart** | Gigabyte B650 Eagle AX WiFi 6E | 6.995 | ✅ |
| 3 | **GPU** | AMD Radeon RX 9070 XT 16GB | ~33.000 | ✅ Doğrulandı |
| 4 | **RAM** | Kingston 32GB (2x16) DDR5 6400MHz CL32 | ~6.318 | ✅ |
| 5 | **SSD** | Kingston NV3 2TB PCIe 4.0 NVMe | 10.999 | ✅ |
| 6 | **PSU** | MSI MAG A750GL Gen5.1 750W 80+ Gold | 5.143 | ✅ |
| 7 | **Kasa** | BitFenix Enso Mesh ARGB E-ATX | 2.726 | ✅ |
| 8 | **CPU Soğutucu** | Thermalright Phantom Spirit 120 SE | 1.999 | ✅ |
| 9 | **Monitör** | Philips Evnia 27M2N3501PA 27" 2K IPS 260Hz | 10.599 | ✅ |
| 10 | **UPS** | Tunçmatik Lift 1500VA Line-Interactive | 5.717 | ✅ |
| 11 | **Koltuk** | Seduna Maxim UP Çalışma Koltuğu | 5.199 | ✅ |
| 12 | **Klavye+Mouse** | Logitech MK295 Silent Kablosuz Set | 1.255 | ✅ |
| | | **TOPLAM** | **~97.263 TL** | |

> **Daha ucuz alternatif:** RX 9070 (non-XT, ~27.000 TL) kullan → toplam ~91.263 TL, ~8.737 TL bütçe fazlası

---

## ROCm vs CUDA — AI için Karşılaştırma

| Kriter | NVIDIA (CUDA) | AMD (ROCm) |
|--------|-------------|-----------|
| **PyTorch** | ✅ Mükemmel | ⚠️ Çoğu model çalışır |
| **TensorFlow** | ✅ Mükemmel | ⚠️ Sınırlı destek |
| **Ollama** | ✅ Sorunsuz | ✅ Son sürümlerde iyi |
| **llama.cpp** | ✅ GGUF + CUDA | ✅ Vulkan ile çalışır |
| **vLLM** | ✅ Tam destek | ⚠️ Deneysel |
| **Stable Diffusion** | ✅ Mükemmel | ✅ ROCm ile iyi (SDXL dahil) |
| **Kurulum** | Basit (`pip install`) | Ek adımlar gerekebilir |
| **Dokümantasyon** | Mükemmel | Gelişiyor |

**Özet:** ROCm 2026 itibarıyla çoğu popüler framework'te çalışıyor. Ollama ve llama.cpp gibi araçlar AMD GPU'ları da destekliyor. Ama CUDA hâlâ "tak ve çalıştır" deneyimi sunuyor.

---

## VRAM Karşılaştırması — Hangi Modeller Çalışır?

| Model Boyutu | Quantization | RX 9070/XT (16GB) | RTX 3090 2. El (24GB) |
|-------------|-------------|-------------------|----------------------|
| 7B (Mistral/Llama 3) | 4-bit | ✅ Çalışır | ✅ Çalışır |
| 13B (Llama 2) | 4-bit | ✅ Çalışır | ✅ Çalışır |
| 30B (Yi/Zephyr) | 4-bit | ⚠️ Sınırda | ✅ Çalışır |
| 70B (Llama 3) | 4-bit | ❌ Taşmaz | ⚠️ Sınırda (32GB gerek) |

---

## Artılar

- RX 9070 XT: RTX 5070 seviyesinde raster performans, RTX 5060 Ti'dan çok daha iyi
- 16GB VRAM + 256-bit bellek yolu — AI'da RTX 5060 Ti'dan belirgin avantaj
- B650 anakart ile Ryzen 9000 yükseltme yolu açık
- FSR 4 desteği (DLSS 3.5 benzeri)
- ROCm ekosistemi hızla olgunlaşıyor

## Eksiler

- CUDA ekosistemi hâlâ daha olgun (TensorRT, cuDNN, özel optimizasyonlar)
- Bazı AI araçları ROCm'de ek yapılandırma gerektirir
- Ray Tracing'de RTX 5070 gerisinde
- Güç tüketimi RTX 5060 Ti'dan yüksek (~260W vs ~150W)

## Kimler İçin?

- **AI/LLM çalıştıracak** ama NVIDIA fiyatlarına girmek istemeyen
- **Ara sıra oyun da oynayacak** (1440p yüksek ayarlar)
- **ROCm ile uğraşmaya istekli** olan
- **FSR 4 / görüntü kalitesi** önemseyen
