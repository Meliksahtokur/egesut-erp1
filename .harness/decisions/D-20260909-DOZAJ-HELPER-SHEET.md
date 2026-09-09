---
id: D-20260909-DOZAJ-HELPER-SHEET
date: 2026-09-09
status: accepted
head: 663ef17
---

# D-20260909 — Dozaj Helper Sheet ve Standart Doz Veri Modeli

## Context

Tedavi/uygulama akışlarında doz, kullanıcının elle yazdığı ham sayıydı;
`hayvanlar.canli_agirlik` ve `drug_products.concentration` verileri doz
hesabında hiç kullanılmıyordu. Saha testi (2026-09-09): 💡 doz önerisi ilk
sürümde "tek değer yaz" modeliydi; sahibin geri bildirimleriyle akış
**tek duraklı helper sheet**'e evrildi:

1. Dozaj bilgisi iki kartta yaşar: hayvan kartında **yalnız kilo**
   (`canli_agirlik`), ilaç kartında **yalnız dozajlama oranları**
   (`drug_products.std_dose + std_dose_unit + std_dose_min/max +
   concentration`). Hayvan kartına asla doz yazılmaz.
2. Pratik doz girişi saha dilidir: **"X kg'a Y ml"** çifti (50 kg / 2 ml);
   helper oranı çıkarır (Y÷X ml/kg) ve toplam kiloya uygular.
3. Sheet'te kullanıcı **neyi değiştirdiyse o kazanır** (pratik çifti mi,
   mg/kg oranı mı) — öndolum asla kullanıcı girişini ezmez.
4. Min/Max prospektüs aralığıdır (aynı oranda); karşısındaki 📥 butonları
   o dozu kilo ile canlı hesaplayıp tedaviye yazar.
5. 💡 tıkla-akışı: hiçbir değer otomatik yazılmaz; sheet açılır, çip tıkla =
   kartlara yaz + doz kutusuna aktar + sheet kapan. "💾 Kartlara yaz"
   sheet'i kapatmaz — planlamada kaldığın yerden devam edilir.

## Decision

- `drug_products` şeması: `std_dose numeric`, `std_dose_unit
  ('ml/kg'|'mg/kg'|'ml/hayvan')`, `std_dose_min/max numeric` (CHECK'li,
  migration `20260909100000` + `20260909110000`).
- İlaç kartı dozaj yazımı yalnız RPC'den geçer: `ilac_dozaj_guncelle(uuid,
  jsonb)` — yalnız gönderilen anahtarları yazar (min≤max doğrulamalı).
  Kilo yazımı `hayvan_kilo_guncelle(text, numeric)` (tek amaçlı; çok
  overload'lu `hayvan_guncelle`'ye minimal çağrı PostgREST'te belirsizlik
  hatası verir).
- Hesap motoru frontend'de saf fonksiyonlardadır (`helpers.js:dozOner`,
  `dozCipleri`); RPC sözleşmeleri değişmez.
- Görevler sekmesi listeleme düzeni: **saat → hayvan grubu
  (`GOREV_GRUP_SIRA`) → küpe doğal sıra**; `#task-srch` veri-katmanı
  içerik aramasıdır (kupe/tip/açıklama/ilaç/teşhis; geçişlerde korunur).
- Helper sheet repo modal desenini kullanır (`.mo` + `.modal`): mobilde
  alt-sheet, geniş ekranda ortalanmış compact kart (max-width 560).

## Consequences

- Seed verileri (26 ilaç kartı dozu, 11 kart aralığı, 12 aşı kartı) demo
  DB'de canlıdır; **PROD migration deploy ayrı onay kapısıdır**.
- Yeni ilaç girişinde standart doz/min/max alanları stok formuna eklenmelidir
  (bilinçli borç — şimdilik sheet üzerinden de girilebilir).
- Çok-overload'lu RPC'lere minimal parametreyle çağrı atlanmaz; tek amaçlı
  RPC yazılır (PostgREST "could not choose best candidate" dersi).
- Dozaj sheet'inin göründüğü 4 giriş noktası: toplu vaka seans satırı,
  vaka detayı seans ekleme, seans düzenleme, hızlı uygulama (pu) modalları.
  Tohumlama ek uygulamaları bilinçli borçtur.
- `'Meme içi'` uygulama yolunun DB CHECK listelerine eklenmesi ayrı
  migration'da bekler (frontend 88b311b'de eklenmişti).
