# Eksikler, Zayıf Noktalar ve Riskler

## 1. Kapasite Kontrolü Eksikliği 🔴

| Yön | Detay |
|-----|-------|
| **Sorun** | `padok_degistir` ve `padok_degistir_toplu` RPC'leri hedef padok kapasitesini kontrol etmez. `padoklar.kapasite` kolonu DB'de var, frontend'de gösteriliyor ama transfer öncesi kontrol yok. |
| **Risk** | Kapasite üzeri hayvan transferi → fiziksel padok kapasitesi aşımı. Hayvan refahı sorunu. |
| **Nerede** | `js/ui.js:5545-5578` (`padokTransferOnayla`) + her iki RPC |
| **Çözüm** | RPC'ye kapasite kontrolü eklenmeli. Mevcut hayvan sayısı (`COUNT WHERE padok_id = hedef AND durum = 'Aktif'`) kapasiteden az olmalı. |

## 2. Grup→Padok Uyum Kontrolü Eksikliği 🟠

| Yön | Detay |
|-----|-------|
| **Sorun** | Transfer UI'da hedef padok seçilirken, hayvanın grubuna uygun padok olup olmadığı kontrol edilmez. GRUP_PADOK mapping'inden bağımsız çalışır. |
| **Risk** | Sağmal inek "Besi Padok (Erkek)"e taşınabilir. Domain kuralı ihlali. |
| **Nerede** | `_pdTransferAcSelector()` (5531-5543) — tüm padokları listeler, sadece kaynak padok hariç |
| **Çözüm** | Seçili hayvanların gruplarına göre hedef padokları filtrele. Ortak uyum varsa sadece onları göster. |

## 3. Otomatik Grup→Padok Ataması Yok 🔴

| Yön | Detay |
|-----|-------|
| **Sorun** | `animalGrupDegisti()` sadece dropdown doldurur, otomatik seçim yapmaz. Tek istisna: **Besi grubu** — cinsiyete göre padok otomatik seçilir (`app.js:351-356`). |
| **Etki** | "p1" sorununun kök nedeni. Hayvan eklenirken padok seçilmezse default 'P1' kalır. Grup değişince padok manuel güncellenmeli. |
| **Nerede** | `app.js:335-357` |
| **Tarihçe** | Eskiden `trg_gebe_grup` trigger'ı vardı (tohumlama sonucu 'Gebe' olunca düveleri 'Gebe Düve' + Kuru/Gebe Padok'a taşırdı). Migration 027'de kaldırıldı — süt veren inekler de tohumlanabildiği için hatalı sonuç üretiyordu. |
| **Çözüm** | `hayvan_guncelle` RPC'sine grup→padok otomatik atama eklenebilir. Veya `animalGrupDegisti()` fonksiyonuna: dropdown tek seçenek içeriyorsa otomatik seç. |

## 4. Transfer UI — UX Katman Fazlalığı 🟠

| Yön | Detay |
|-----|-------|
| **Sorun** | Mevcut akış: `m-padok-det` aç → checkbox seç → "Toplu Taşı" butonu → `m-padok-transfer` modal → dropdown'dan seç → "Taşı" butonu. Toplam **3 katman** (detay modal, içinde liste, transfer modal). |
| **Risk** | Kullanıcı kaybolur. "Neyi nereye taşıyorum" sorusu sık sorulur. |
| **Öneri** | `.claude/ideas/padok-transfer-ux.md`'de bottom action bar + inline dropdown pattern'i önerilmiş. Sürü dashboard'da uzun basışla seçim, altta action bar, inline padok seçimi. 0 modal. |
| **Ek not** | Feature status dokümanındaki line numaraları (`ui.js:3873-3950`) güncel değil. Gerçek satırlar: `5454-5578`. Demek ki kod refactor edilmiş ama döküman güncellenmemiş. |

## 5. Cross-Padok Seçim Yok 🟡

| Yön | Detay |
|-----|-------|
| **Sorun** | Transfer UI sadece **tek bir padok içindeki** hayvanları seçip taşıyabiliyor. Birden fazla padoktan hayvan seçip tek hedefe taşıma yok. |
| **Senaryo** | "Buzağı padok (Süt İçenler)"de 3 + "Buzağı padok (Sütten Kesilmiş)"de 2 hayvanı topluca "Düve Padok (Küçük)"e taşı. Mevcut UI'da iki kere yapmak gerekir. |
| **Çözüm** | Sürü listesi/dashboard'dan çoklu padok seçimi yapılabilir. |

## 6. Görev Tamamlama → Padok Transferi Tutarsızlığı 🟡

| Yön | Detay |
|-----|-------|
| **Sorun** | `doneTask()` fonksiyonu `gorev_tamamla` RPC'sine `p_padok_hedef` gönderiyor. Bu parametre `gorev_log.padok_hedef` kolonundan geliyor. Ama bu kolon çoğu görevde boş (null). |
| **Risk** | `padok_hedef` = null gönderilince RPC ne yapıyor? Ya hayvanın padok'u değişmiyor ya da hata fırlatıyor. Kod şu anda `gorev_tamamla` RPC'sinin bodysini tam okumadım. |
| **Nerede** | `forms.js:826-841`, `ui.js:5148-5151` |

## 7. Mevcut Araştırma/Plan Dokümanları Güncelliği 🟢

| Durum | Detay |
|-------|-------|
| `.claude/notes/padok-transfer-arastirma.md` | Büyük ölçüde güncel. Eksikler kısmı hala geçerli. |
| `.claude/ideas/padok-transfer-ux.md` | Hala fikir aşamasında, implementasyon bekliyor. |
| `docs/feature-status-2026-05-13.md` | Line numaraları eski (3873 vs 5454). Güncellenmeli. |

## 8. Kapasite / Risk Matrisi

| # | Eksik | Önem | Etki | Çözüm Maliyeti |
|---|-------|------|------|----------------|
| 1 | Kapasite kontrolü | 🔴 Kritik | Operasyonel hata | Orta (RPC + frontend) |
| 2 | Grup→padok uyum | 🟠 Yüksek | Domain ihlali | Düşük (frontend filtre) |
| 3 | Otomatik atama | 🔴 Kritik | "p1" sorunu | Orta (RPC + trigger) |
| 4 | UX katman | 🟠 Yüksek | Kullanılabilirlik | Yüksek (büyük UI değişikliği) |
| 5 | Cross-padok | 🟡 Orta | Kullanıcı talebi | Yüksek (yeni UI) |
| 6 | Görev tutarsızlık | 🟡 Orta | Veri bütünlüğü | Düşük (test + fix) |
