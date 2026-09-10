# Dogfood Dersleri (hızlı erişim)

> **Kaynak:** `research/2026-06-29-dogfood-pc-build-v0.1/01-RAPOR-dogfood.md`
> **Aksiyon listesi:** `research/2026-06-29-dogfood-pc-build-v0.1/02-BULGULAR-aksiyonlar.md`

Bu dosya dogfood sırasında tespit edilen **en önemli 10 noktayı** özetler. Skill'i her kullanışta bu listeyi gözden geçir.

---

## 🔴 Bilinen güvenilmez alanlar (sonuç KULLANMA, fallback dene)

1. **Corsair ürünlerinin tümü** → "ylmzhome" satıcısı 3-5× pahalı listeliyor, çıktı güvenilmez.
   Fallback: MSI MAG A650GL, FSP Hydro, be quiet! Pure Power markaları.
2. **Seasonic ürünleri** → Benzer anomali, 650W varyantı aramada bulunmuyor.
3. **"Corsair RM650x 80 Plus Gold" araması** → Klima + tablet döndürüyor, PSU yok.
4. **Akakçe search sonuçlarında 2-5. sıra** → %80 iPhone/Samsung/kategori-dışı spam. **İlk sonuca odaklan, sonrasını göz ardı et.**

## 🟡 Sorgu yazarken

- **Kısa jenerik sorgular** spesifik tam-ürün adlarından daha iyi çalışıyor.
  - ❌ `Corsair RM650x 80 Plus Gold` → klima
  - ✅ `Corsair RM650` → doğru PSU
  - ❌ `G.Skill Trident Z5 32GB 6000 DDR5` → 26k TL (pahalı varyant)
  - ✅ `GSkill Ripjaws S5 32GB 6000 DDR5` → 24k TL gerçekçi
- **WD Black SN770** araması SN7100/SN850X karıştırıyor → SN770 doğrudan yok.
- **"DeepCool CC360"** Akakçe'de kayıtlı değil gibi.
- **"Zalman S2 TG"** Akakçe'de kayıtlı değil gibi.

## 🟢 Güvenilir parça/kategori kombinasyonları

- **CPU (Ryzen 5 7600, 5600, 7700X)**: yüksek offer_count (43-159), gerçekçi fiyat.
- **Anakart (MSI B650 Gaming Plus WiFi)**: 43 offer, 9.952 TL tutarlı.
- **SSD (Samsung 990 EVO Plus 1TB)**: 177 offer, 8.999 TL MediaMarkt.
- **Kasa (MSI MAG Forge 100R)**: 108 offer, 2.659 TL.
- **GPU (RTX 5060 Ti 8GB)**: 144 offer, 19.499 TL.

## ⚠️ Spec eksikliği uyarısı

`specs: {}` olan ürünlerde `confidence=VERIFIED` dönüyor — bu **yanıltıcı.**
- **Cooler Master Hyper 212 Black** → specs boş, sadece başlıktan AM5 uyumu teyit edildi.
- **WD Black SN850X** → `brand: null`.
- **Corsair CV650 / RM650** → `"Verimlilik": "80%"` (tier belirsiz).

Bunlarda check_compat.py'a `tdp_rating` veya `80+ tier` girilemez → **WARN olarak kalır.**

## 🛠 validate_run.py sınırlamaları

- **Bütçe kontrolü YOK.** 35k bütçeye 84k sepet çıktı, uyarı yok.
- **Multi-provider YOK.** Tek Akakçe → outlier tespiti imkânsız.
- **Outlier filtreleme YOK.** ylmzhome gibi mağazalar sonuçları kirletiyor.

## 📊 offer_count yorumlama

- **offer_count ≥ 20:** Fiyat teyidi güçlü, güvenle kullan.
- **offer_count 5-19:** Tek mağaza bandı, fiyat doğrulaması zayıf.
- **offer_count 1-2:** TEK MAĞAZA — outlier şüphesi yüksek. **Çapraz kontrol şart.**

## 🔁 Aynı ürün için alternatif sorgular

| Ürün | Sorgu | Aldığı sonuç |
|---|---|---|
| RAM 32GB 6000 | `G.Skill Trident Z5 32GB 6000 DDR5` | 26k TL (pahalı RGB Neo) |
| | `G.Skill Ripjaws S5 32GB 6000 DDR5` | 24k TL (gerçekçi, non-RGB) |
| | `Crucial Pro 32GB 6000` | 25.9k TL (Crucial, gerçekçi) |
| PSU 650W | `Corsair RM650x 80 Plus Gold` | klima (KÖTÜ) |
| | `Corsair RM650` | doğru PSU (24k TL → outlier) |
| | `Corsair CV650` | doğru PSU (9.999 TL OK) |
| | `MSI MAG A650GL` | doğru PSU (14k TL Gold) |

**Kural:** İlk arama alakasız sonuç verirse, sorguyu kısalt veya marka+seri (model no) formatına geç.

## 📁 Sepet kompozisyon notu (35k TL gerçekçi mi?)

**HAYIR.** DDR5 + AM5 + 32GB + RTX 5060 Ti → **gerçekçi eşik 75-90k TL.**

35k'ye sığdırmak için:
- Ryzen 5 **5600** (AM4/DDR4) + **16GB** + RX 9060 XT 8GB → ~32-38k TL
- VEYA bütçeyi **75-90k TL'ye** çıkar.

Bu skill bütçe uyumluluğunu **sorgulamıyor** (P1-2 aksiyonu).

## 🗂 İlgili dosyalar

- Detaylı rapor: `research/2026-06-29-dogfood-pc-build-v0.1/01-RAPOR-dogfood.md`
- Aksiyon listesi: `research/2026-06-29-dogfood-pc-build-v0.1/02-BULGULAR-aksiyonlar.md`
- Skill kaynak: `SKILL.md`, `references/research-contract.md`
