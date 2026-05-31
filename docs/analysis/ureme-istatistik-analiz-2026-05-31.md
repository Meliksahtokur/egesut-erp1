# Üreme İstatistikleri — Analiz Raporu

**Tarih:** 2026-05-31
**Sonuç:** Algoritma doğru. Sorun seed data'daki şüpheli Boş kayıtlarında.

---

## 1. Bulgular

### 1.1 Algoritma — Doğru ✅

| Bileşen | Durum | Açıklama |
|---------|-------|----------|
| Cycle tespiti | ✅ | `deneme_no=1` ile doğru ayrılıyor |
| Cycle sonucu | ✅ | `bool_or` öncelik sırası: Gebe > Abort > Bekliyor > Boş |
| Sperma attribution | ✅ | Başarılı cycle → gebe_sperma, başarısız → son_sperma. Repeat'ler bilinçli düşülüyor |
| Bekliyor filtreleme | ✅ | `WHERE sonuc != 'Bekliyor'` ile hesaba dahil edilmiyor |
| Son Dönem filtresi | ✅ | Son gebelikten sonraki cycle'lar doğru filtreleniyor |
| Hayvan bazlı sonuç | ✅ | Son cycle'ın sonucu doğru alınıyor |
| Düve sınıflandırması | ✅ | `grup ILIKE '%düve%'` + doğum kontrolü doğru |
| Frontend render | ✅ | Sadece gösterim yapıyor, hesap yok |

### 1.2 Veri Kalitesi — Sorunlu ⚠️

| Metrik | Değer |
|--------|-------|
| Toplam tohumlama kaydı | 245 |
| Seed data (9 Mayıs 2026 toplu import) | 244 |
| Gerçek UI girişi | 1 |

Seed data: `apply.py` benzeri script ile Supabase API üzerinden 27 dakikada toplu girilmiş. `payload=null`, `kullanici_notu=null`, tüm kayıtlar aynı saniyede.

### 1.3 Son Dönem Boş Cycle'ların Kaynağı

| Durum | Sayı |
|-------|------|
| ✅ Onaylı Boş (TOHUMLAMA_SONUC / KIZGINLIK log'lu) | 2 |
| ⚠️ Şüpheli Boş (sadece seed data, onay yok) | 16 |
| **Toplam** | **18** |

**Onaylı Boş'lar (gerçek gözlem):**
- Küpe 152: 16 Mayıs'ta Darius ile tohumlama → aynı gün kızgınlık → 18 Mayıs'ta Boş işaretlenmiş
- Küpe 189: TOHUMLAMA_SONUC log'lu

**Şüpheli Boş'lar (seed data varsayımı):**

| Küpe | Grup | Son Sperma | Deneme |
|------|------|------------|--------|
| 01 | Düve (Büyük) | fresh | 1 |
| 15 | Düve (Büyük) | bonum | 1 |
| 201 | Düve (Büyük) | starred | 1 |
| 202 | Düve (Büyük) | darius | 1 |
| 203 | Düve (Büyük) | darius | 2 |
| 205 | Düve (Büyük) | starred | 1 |
| 206 | Düve (Büyük) | starred | 2 |
| 208 | Düve (Büyük) | starred | 2 |
| 134 | Sağmal | darius | 1 |
| 142 | Sağmal | starred | 2 |
| 150 | Kuru | starred | 1 |
| 151 | Sağmal | fresh | 4 |
| 167 | Sağmal | darius | 3 |
| 197 | Sağmal | sincleir | 1 |
| 900 | Sağmal | glomoris | 2 |
| 902 | Sağmal | darius | 1 |

### 1.4 Mevcut İstatistik vs Düzeltilmiş

| Metrik | Mevcut (şüpheli Boş'lar dahil) | Düzeltilmiş (şüpheliler Bekliyor) |
|--------|-------------------------------|----------------------------------|
| Başarılı cycle | 62 | 62 |
| Başarısız cycle | 21 (20 Boş + 1 Abort) | 4 (2 Boş + 1 Abort + 1?) |
| Devam eden | 11 | 11 + 16 = 27 |
| **Cycle oranı** | **%74.7** | **%93.9** |
| Hayvan oranı | %66.1 | Değişir |

### 1.5 Diğer Gözlemler

**Tohumlama kaydı olmayan hayvanlar:**
- 10 düve + 6 inek = 16 dişi hiç tohumlanmamış
- İstatistikte görünmüyorlar (normal)
- Dashboard'da "Tohumlanmamış: X düve, Y inek" notu eklenmeli

**Bekliyor cycle'lar:**
- Toplam 11 Bekliyor (6 darius, 4 fresh, 1 campus)
- 194 (e14f4fb6) 247 gündür Bekliyor — sonuçlandırılmalı
- 195 (bac3b8f8) 72 gündür Bekliyor — sonuçlandırılmalı

**UI isimlendirme önerisi:**
- "Hayvan Bazlı Sonuç" → "Hayvan Durumu" (daha açıklayıcı)

### 1.6 Gözden Kaçanlar (Raporda Eksik Kalan)

**Sperma Top 5 — sadece %100'ler gösteriliyor:**
Tüm Zamanlar'da naika red (3/3), bale red (4/4), armada red (24/24), pascored (11/11), fresco red noncorn (4/4) — hepsi %100. Darius (1/7), fresh (1/4), starred (34/42) listede yok. Neden? `ORDER BY oran DESC` yapılıyorsa ilk 5 slot'u %100'ler dolduruyor, sorunlu spermalar alta kayıp görünmez oluyor. **Öneri:** limit'i artır veya en az 1 başarısızı olan spermaları ayrı göster.

**Demografik toplamı:**
66 inek + 20 düve + 3 buzağı + 1 kısır = 90, ama UI'da 89 yazıyor. 1 hayvanlık fark — muhtemelen bir hayvan iki kategoride sayılıyor ya da durum filtresinde edge case var.

**Düve Boş'ların seed data durumu:**
8 Boş düveden en az 5'i (01, 15, 201, 202, 203, 205, 206, 208 — küpe numaraları) seed data kaynaklı şüpheli. Düzeltilirse düve oranı %20'den çok daha yükseğe çıkar.

---

## 2. Aksiyon Planı

| # | Eylem | Öncelik |
|---|-------|---------|
| 1 | 16 şüpheli Boş cycle'ın sonucunu güncelle (Bekliyor veya gerçek gözleme göre) | 🔴 |
| 2 | 194 (247 gün) ve 195 (72 gün) Bekliyor'ları sonuçlandır | 🔴 |
| 3 | Dashboard'a tohumlanmamış hayvan sayısını ekle | 🟡 |
| 4 | Sperma kartında Bekliyor sayısını göster: "darius: 1/2 (%50) · ⏳ 6 bekliyor" | 🟡 |
| 5 | "Hayvan Bazlı Sonuç" → "Hayvan Durumu" isim değişikliği | 🟢 |
