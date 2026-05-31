# Ek Keşif — Web'de Bulunan Diğer Kaynaklar

**Yöntem:** Geniş çaplı web araması (DuckDuckGo)

---

## GitHub Repoları

| Repo | Neden İlgili | Özet |
|------|-------------|------|
| **DPoitrast/MCP** — `bovisync_mcp/` | BoviSync MCP sunucusu! | BoviSync API'sini MCP (Model Context Protocol) ile sarmış. Bizim tools-bank MCP sunucumuza benzer. İçindeki endpoint listesi ve veri modeli referans alınabilir |
| **plantbreeding/BrAPI-Dataset** | BrAPI standardı SQL şeması | Bitki ıslahı için olsa da, breeding event veri modeli (schema.sql) referans olarak incelenebilir |
| **DairyComp 305 Command Reference PDF** | 46 komut referansı | `dairychallenge.org`'da yayınlanmış resmi olmayan komut rehberi. SUM, BREDSUM, PREG, CONC komutlarının kullanımı |

---

## Akademik/Extension Kaynakları

| Kaynak | Anahtar Bulgu |
|--------|-------------|
| **Kentucky Üni: "Ways to Measure Dairy Reproductive Performance"** | CR = gebe / tohumlanan. PR = gebe / eligible. PR = HDR × CR. 21-gün penceresinde hesaplanır |
| **ADAS: "Key Performance Indicators for Monitoring Fertility"** | 21-day PR en etkili fertilite izleme metriğidir. Non-return rate ve % pregnant en erken uyarıyı verir |
| **Tennessee Üni: "Back to the Breeding Basics"** | HDR = 21 günde tohumlanan / eligible. TAI programları bu oranı yükseltir |
| **UGA: "Dairy Reproduction Benchmarks"** | DFS, CR, HDR → Days Open ve Calving Interval'i belirler |
| **Wisconsin Üni: "BoviSync Reports for Heat Stress"** | BoviSync kullanarak PR trend analizi için R kodu örneği |
| **DCRC (Dairy Cattle Reproduction Council)** | Senkronizasyon protokolleri ve repro benchmark'ları |

---

## SQL/Veri Modeli Örnekleri

| Kaynak | Bulgu |
|--------|-------|
| **ScienceDirect: "Stochastic animal life cycle simulation model"** | Tam bir süt çiftliği simülasyonu veri modeli: initialization DB, animal base file, calf/heifer/cow/culled file'ları, herd simulation file |
| **USDA ARS: "Dairy Cattle Breeding and Genetics"** | Genomik değerlendirme modeli — bizim sperma seçimi için fazla detaylı |

---

## Dashboard/Görselleştirme

- Doğrudan dairy repro dashboard'u olan açık kaynak proje bulunamadı
- Çoğu çiftlik yönetim yazılımı ticari (BoviSync, DairyComp, VAS, UNIFORM-Agri)
- Açık kaynak alternatifler (farmOS) dashboard'dan çok veri girişi odaklı

---

## Hidden Gems

1. **BrAPI standardı:** Bitki ıslahı için geliştirilmiş bir API standardı. Breeding event'lerin nasıl modellendiğini gösteren bir referans şema sunuyor. Hayvancılık için benzer bir standart yok — bizim modelimiz öncü olabilir.

2. **DPoitrast'ın BoviSync MCP'si:** Bir geliştirici BoviSync API'sini MCP protokolüne sarmış. `README.md` içinde API endpoint'leri ve veri modeli hakkında ipuçları olabilir. İncelenmeye değer.

3. **DCRC protokol şablonları:** DCRC'nin yayınladığı senkronizasyon protokol şablonları, bizim `tohumlama` veri modeline `protokol` alanı eklemek için referans olabilir.

4. **Simülasyon modeli (ScienceDirect):** Tam bir süt çiftliği simülasyonunun veri modeli. `calf → heifer → cow → culled` yaşam döngüsü state machine'i bizim `hayvan_durum` mantığımıza benzer.
