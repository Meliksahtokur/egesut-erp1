# Setup 0: API + Multi-Agent İstasyonu — ★ YENİ ÖNERİLEN

> **Paradigma Değişikliği (23 Mayıs 2026):** Lokal LLM (VRAM) hamallığından kurtulup, API tabanlı otonom Multi-Agent, paralel süreçler, Docker ve mikroservisler için saf işlemci/okuma-yazma gücüne odaklanıyoruz. GPU'dan tasarruf edilen ~15.000 TL doğrudan CPU'ya yatırıldı.

---

## Strateji

**Eski yaklaşım:** VRAM biriktir, lokal LLM çalıştır (30B+ modeller)
**Yeni yaklaşım:** API ile AI (OpenAI/Claude), parayı işlemci gücüne yatır

| Kriter | Eski (Setup 1-7) | Yeni (Setup 0) | Fark |
|--------|-----------------|----------------|------|
| **GPU** | RTX 5070 12GB / RTX 3090 24GB | RTX 4060 Ti 8GB | ~15.000 TL daha ucuz |
| **CPU** | Ryzen 5 6C/12T | **Ryzen 9 9900X 12C/24T** | 2× çekirdek, Zen 5 |
| **SSD** | NV3 (DRAM'siz) | **KC3000 (DRAM'li)** | Sıfır I/O darboğazı |
| **RAM** | 32GB 6400MHz CL32 | 32GB 6400MHz CL32 | Aynı (stabilite korundu) |
| **AI Yöntemi** | Lokal LLM (VRAM'a bağımlı) | **API tabanlı** | VRAM yükü sıfır |
| **Toplam** | ~89.000-96.000 TL | **~99.335 TL** | Bütçenin milimetrik kullanımı |

---

## Felsefe: "Ekran kartı yarı yolda bırakmasın yeter"

Bu setup'ın temel kuralı: GPU'nun görevi 2 adet 2K monitörü beslemek, hardware acceleration sağlamak ve ara sıra 1440p oyun oynatmak. VRAM biriktirmenin anlamı yok çünkü:

1. **API çağrıları VRAM tüketmez** — AI yükü sende değil, bulutta
2. **Multi-agent süreçleri CPU/thread tüketir** — GPU'ya dokunmaz
3. **Docker container'ları RAM/disk tüketir** — GPU'yu meşgul etmez
4. **Derleme işlemleri CPU tüketir** — GPU boşta bekler

> "VRAM'i doldurmayan ama CPU'yu %100'e kilitleyen asenkron Python/Node görevleri, veritabanı sorguları ve tarayıcı otomasyonları (Puppeteer/Playwright) karşısında bu makine tepki süresini zerre kaybetmeden çalışacaktır."

---

## Parça Listesi (Milimetrik Bütçe)

| # | Bileşen | Model | Fiyat (TL) | Stratejik Gerekçe |
|---|---------|-------|-----------|-------------------|
| 1 | **CPU** 🏆 | **AMD Ryzen 9 9900X** (12C/24T, Zen 5, 4.4GHz base) | **~19.739** | **Paradigma değişiminin odağı.** 24 thread ile 10+ paralel agent, ağır derleme, container orkestrasyonu. Ryzen 5'e göre %100'e yakın performans artışı. |
| 2 | **GPU** | Zotac/Gigabyte **RTX 4060 Ti 8GB** GDDR6 | **~20.266** | "Yarı yolda bırakmayacak" kart. 2× 2K monitör, CUDA, DLSS 3, hardware acceleration. Atıl VRAM'a para vermiyoruz. |
| 3 | **Anakart** | Asus TUF Gaming B650-E WiFi (VRM: 12+2 faz) | **7.849** | 12 çekirdekli 9900X'i besleyecek güçlü VRM. PCIe 5.0, WiFi 6, Ryzen 9000 native. |
| 4 | **RAM** | Kingston 32GB (2×16) DDR5 6400MHz CL32 | **~6.318** | 4×16GB AM5 stabilite riskine girmeden, Dual-Channel maksimum stabilite. 32GB API + Docker + IDE için fazlasıyla yeterli. |
| 5 | **SSD** 🏆 | **Kingston KC3000 2TB** PCIe 4.0 (DRAM Cache) | **~16.474** | **DRAM Cache kuralı.** Milyonlarca satır log yazan agent'lar, sürekli yazma yapan container'lar ve derleme çıktıları DRAM'siz SSD'de takılır. KC3000 farkı budur. |
| 6 | **PSU** | MSI MAG A750GL Gen5.1 750W 80+ Gold | **5.143** | CPU (120W) + GPU (160W) = ~280W yük altında. 750W sessiz ve serin çalışma demek. Gen5.1 hazır. |
| 7 | **Soğutucu** | Thermalright Phantom Spirit 120 SE (Çift Kule) | **1.999** | 12 çekirdekli 9900X'i sıvı soğutma riski olmadan (pompa arızası, sızıntı) rahatça dizginler. |
| 8 | **Kasa** | BitFenix Enso Mesh ARGB E-ATX | **2.726** | Tam mesh ön panel, kesintisiz hava akışı. |
| 9 | **Monitör** | Fazeon 27" 2K IPS 150Hz | **6.650** | 2K çözünürlük, kod + terminal için ideal piksel yoğunluğu. 150Hz akıcılık. |
| 10 | **UPS** | Tunçmatik Lift 1500VA Line-Interactive | **5.717** | Şebeke koruması, ani kapanmalarda veri kaybı önleme. |
| 11 | **Koltuk** | Seduna Maxim UP Çalışma Koltuğu | **5.199** | Uzun oturumlar için ergonomi. |
| 12 | **Klavye+Mouse** | Logitech MK295 Silent Kablosuz Set | **1.255** | Sessiz, güvenilir, pil ömrü uzun. |
| | | **TOPLAM** | **~99.335 TL** | **100.000 TL bütçenin milimetrik kullanımı ✅** |

---

## Ryzen 9 9900X — Neden Bu CPU?

| Kriter | Ryzen 5 7600 (Eski) | Ryzen 9 9900X (Yeni) | Fark |
|--------|-------------------|---------------------|------|
| **Çekirdek/Thread** | 6C/12T | **12C/24T** | **2×** |
| **Mimari** | Zen 4 | **Zen 5** | +%16 IPC |
| **Max Boost** | 5.1 GHz | **5.6 GHz** | +%10 |
| **L3 Cache** | 32MB | **64MB** | 2× |
| **TDP** | 65W | 120W | Soğutma şart |
| **Cinebench R23 Çok** | ~15.200 | **~33.000** | **+%117** |
| **Kod Derleme (Linux kernel)** | ~178 sn | **~95 sn** | **%47 daha hızlı** |
| **Fiyat** | ~7.313 TL | ~19.739 TL | +12.426 TL |

> 12.426 TL farka 2× çekirdek, %117 çoklu işlem performansı, %47 daha hızlı derleme.
> GPU'dan tasarruf ettiğimiz ~15.000 TL'nin ~12.500 TL'sini CPU'ya harcadık, kalan ~2.500 TL SSD'ye.

---

## Bu Setup Kimin İçin?

- **Multi-Agent sistemleri geliştiren** (LangChain, CrewAI, AutoGen, DeerFlow)
- **API tabanlı AI kullanan** (OpenAI, Anthropic, DeepSeek API)
- **Ağır Docker/container iş yükleri** çalıştıran (10+ container aynı anda)
- **Mikroservis mimarisi** geliştiren
- **Paralel test/Pipeline** koşturan (CI/CD, Playwright, Puppeteer)
- **Lokal LLM ihtiyacı olmayan** (VRAM hamallığı yok)

## Bu Setup Kimin İçin DEĞİL?

- ❌ Lokal 30B+ LLM çalıştıracaklar (24GB VRAM gerek)
- ❌ Stable Diffusion / görüntü üretimi yapacaklar
- ❌ AAA oyunları 4K Ultra'da oynayacaklar
- ❌ CUDA üzerinde ağır model eğitecekler

---

## Karşılaştırma: Eski Öneri (Setup 1) vs Yeni Öneri (Setup 0)

| Kriter | ★ Eski: Setup 1 (OEM 5070) | ★ Yeni: Setup 0 (API Agent) |
|--------|---------------------------|----------------------------|
| **Toplam** | ~89.434 TL | **~99.335 TL** |
| **CPU** | Ryzen 5 7500F (6C/12T) | **Ryzen 9 9900X (12C/24T)** 🏆 |
| **GPU** | RTX 5070 12GB | RTX 4060 Ti 8GB |
| **RAM** | 16GB (OEM) | **32GB 6400MHz CL32** 🏆 |
| **SSD** | NV3 2TB (DRAM'siz) | **KC3000 2TB (DRAM'li)** 🏆 |
| **AI Yöntemi** | Lokal LLM (12GB VRAM) | **API tabanlı** 🏆 |
| **Multi-Agent** | 6 thread (darboğaz) | **24 thread** 🏆 |
| **Derleme Hızı** | ~178 sn (Linux kernel) | **~95 sn** 🏆 |
| **1440p Oyun** | ⭐⭐⭐⭐⭐ 🏆 | ⭐⭐⭐ |
| **Garanti** | OEM tek | Parça parça |
| **Bütçe Kullanımı** | ~10.000 TL fazla | **Milimetrik** 🏆 |

---

## Güç Tüketimi ve Termal Analiz

| Bileşen | TDP | Yük Altında | Boşta |
|---------|-----|-------------|-------|
| Ryzen 9 9900X | 120W | ~150W (boost) | ~30W |
| RTX 4060 Ti 8GB | 160W | ~150W | ~15W |
| Anakart + RAM + SSD | ~50W | ~60W | ~30W |
| **Toplam Sistem** | **~330W** | **~360W** | **~75W** |

> 750W PSU ile sistem %48 yükte çalışır — sessiz ve verimli.
> 1500VA UPS ~900W kapasite → ~5-7 dakika kesintisiz çalışma süresi.

---

## Kurulum Notları

- **BIOS güncellemesi şart** — B650 anakart Ryzen 9000 serisi için güncel BIOS gerektirir
- **RAM'i 2. ve 4. slotlara tak** — Dual Channel stabilitesi için
- **Windows 11 önerilir** — Intel/AMD thread scheduler optimizasyonu için
- **WSL2 kur** — Docker Desktop yerine WSL2 backend ile daha iyi performans
- **KC3000'ü ana M.2 PCIe 5.0 slotuna tak** — Anakart destekliyorsa tam hız
