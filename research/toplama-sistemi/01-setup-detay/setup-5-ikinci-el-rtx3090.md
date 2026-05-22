# Setup 7: 2. El RTX 3090 — 24GB VRAM ile Lokal LLM Devrimi 🆕

**Strateji:** İkinci el GPU ile maksimum VRAM, minimal bütçe
**Toplam:** ~86.492 TL
**Kalan Bütçe:** ~13.508 TL
**Kullanım:** Lokal AI/LLM (30B-70B modeller), yazılım geliştirme

---

## Neden 2. El RTX 3090 24GB?

Araştırmanın en büyük kör noktası buydu. RTX 3090 24GB VRAM, 100.000 TL bütçede **30B-70B quantized modelleri lokal çalıştırabilen tek GPU**.

| Karşılaştırma | RTX 5070 (12GB) | RTX 5060 Ti (16GB) | **RTX 3090 2. El (24GB)** |
|--------------|-----------------|-------------------|--------------------------|
| **Fiyat** | 35.243 TL ✅ | 29.419 TL ✅ | **~25.000-30.000 TL** ⚠️ |
| **VRAM** | 12GB ❌ | 16GB ⚠️ | **24GB** 🏆 |
| **Bellek Yolu** | 192-bit | 128-bit ❌ | **384-bit** 🏆 |
| **Bant Genişliği** | ~672 GB/s | ~448 GB/s | **~936 GB/s** 🏆 |
| **AI LLM 30B (Q4)** | ❌ Taşmaz | ⚠️ Sınırda | **✅ Çalışır** |
| **AI LLM 70B (Q4)** | ❌ | ❌ | **⚠️ Sınırda** |
| **Oyun (1440p)** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Garanti** | Sıfır (2 yıl) | Sıfır (2 yıl) | ⚠️ Yok / satıcıya bağlı |
| **Risk** | Düşük | Düşük | Orta-Yüksek (mining, sahte) |

> 🏆 24GB VRAM ile RTX 5070 ve 5060 Ti'ın AI yeteneklerini **katlıyor**.
> 30B modeller (Q4) sorunsuz çalışır, 70B modeller (Q4) sınırda kalır.

---

## Parça Listesi

| # | Bileşen | Model | Fiyat (TL) | Durum |
|---|---------|-------|-----------|-------|
| 1 | **CPU** | AMD Ryzen 5 7600 (MPK) 6C/12T | 7.313 | ✅ |
| 2 | **Anakart** | MSI PRO B650M-B DDR5 (bütçe) | 4.139 | ✅ |
| 3 | **GPU** | **NVIDIA RTX 3090 24GB (2. El)** | **~28.000** | ⚠️ 2. el |
| 4 | **RAM** | Kingston 32GB (2x16) DDR5 6400MHz CL32 | ~6.318 | ✅ |
| 5 | **SSD** | Kingston NV3 2TB PCIe 4.0 NVMe | 10.999 | ✅ |
| 6 | **PSU** | MSI MAG A850GL Gen5 850W (3090 için gerekli) | 6.399 | ✅ |
| 7 | **Kasa** | BitFenix Enso Mesh ARGB E-ATX | 2.726 | ✅ |
| 8 | **CPU Soğutucu** | Thermalright Phantom Spirit 120 SE | 1.999 | ✅ |
| 9 | **Monitör** | Fazeon 27" 2K IPS 150Hz | 6.650 | ✅ |
| 10 | **UPS** | Tunçmatik Lift 1500VA Line-Interactive | 5.717 | ✅ |
| 11 | **Koltuk** | Seduna Maxim UP Çalışma Koltuğu | 5.199 | ✅ |
| 12 | **Klavye+Mouse** | Logitech MK295 Silent Kablosuz Set | 1.255 | ✅ |
| | | **TOPLAM** | **~86.714 TL** | |
| | | **KALAN BÜTÇE** | **~13.286 TL** | |

---

## 2. El GPU Alırken Dikkat Edilmesi Gerekenler

### Risk Faktörleri

| Risk | Olasılık | Etki | Önlem |
|------|---------|------|-------|
| Mining kartı (yorulmuş VRAM) | Orta | Yüksek | Satıcıya mining sorgula, benchmark test et |
| Sahte/yanlış model | Düşük | Çok Yüksek | GPU-Z ile doğrula, seri numarasını kontrol et |
| Garanti yok | Yüksek | Orta | Parça fiyatı kadar riske giriyorsun |
| Soğutucu arızası | Düşük | Yüksek | FurMark ile ısı testi yap |
| Termal pad aşınması | Orta | Orta | 2. el 3090'da pad değişimi gerekebilir |

### Nerden Alınır?

- **Sahibinden.com** — en geniş seçenek, satıcı puanı kontrolü
- **Letgo** — daha az seçenek, pazarlık şansı
- **Epey 2. El** — sınırlı ama güvenilir
- **Teknosa/MediaMarkt 2. El (yenilenmiş)** — garanti var ama fiyat yüksek

### Alırken Yapılması Gereken Testler

```bash
# 1. GPU bilgisi doğrulama
nvidia-smi                   # Model, VRAM, sürücü
# 2. Sıcaklık testi (15dk)
furmark                      # 85°C altı normal
# 3. VRAM testi
python -c "import torch; print(torch.cuda.get_device_properties(0).total_memory)"
# 4. AI inference testi
ollama run llama3:70b        # 70B model çalışıyor mu?
```

---

## VRAM Karşılaştırması

| Model | Quantization | RTX 3090 24GB | RTX 5070 12GB | Fark |
|-------|-------------|--------------|--------------|------|
| Llama 3 8B | Q4_K_M (~5.3GB) | ✅ | ✅ | 4.7x model kapasite |
| Llama 3 70B | Q4_K_M (~41GB) | ⚠️ [1] | ❌ | 12GB yetmez |
| Mistral 7B | Q4_K_M (~4.5GB) | ✅ | ✅ | - |
| Mixtral 8x7B | Q4_K_M (~25GB) | ⚠️ [2] | ❌ | 12GB yetmez |
| DeepSeek Coder 33B | Q4_K_M (~18GB) | ✅ | ❌ | Sadece 24GB ile |
| Qwen 32B | Q4_K_M (~17GB) | ✅ | ❌ | Sadece 24GB ile |
| Command R 35B | Q4_K_M (~19GB) | ✅ | ❌ | Sadece 24GB ile |
| Yi 34B | Q4_K_M (~18GB) | ✅ | ❌ | Sadece 24GB ile |

[1] 70B Q4_K_M ~41GB VRAM gerek — 24GB + sistem RAM offloading ile çalışabilir (yavaş)
[2] Mixtral 8x7B Q4_K_M ~25GB — offloading ile çalışır

---

## Artılar

- **24GB VRAM** — bu bütçede ulaşılabilecek en yüksek VRAM
- **30B-34B modeller full lokal çalışır** (Qwen, Yi, DeepSeek Coder)
- RTX 3090 oyun için hâlâ çok güçlü (~RTX 4070 Ti seviyesi)
- 384-bit bellek yolu — AI inference'da büyük avantaj
- Bütçede ~13.000 TL tampon — 64GB RAM yükseltmesine yetecek kadar

## Eksiler

- **2. el riski** — mining kartı, garanti yok, termal pad değişimi gerekebilir
- **350W TDP** — güç tüketimi yüksek, 850W PSU şart
- **Eski mimari** (Ampere, 2020) — güncel oyunlarda RTX 5070'den yavaş
- **DLSS 3 Frame Generation yok** — RTX 40/50 serisinde var
- **Büyük kasa gerekir** — 3090'lar genelde 3.5 slot

## Kimler İçin?

- **Lokal LLM/agent birincil hedef** olan (30B+ modeller)
- **2. el almaktan çekinmeyen**
- **GPU soğutma/termal konusunda tecrübeli**
- **Yüksek elektrik faturasına razı** (3090 ~350W çeker)
