# Üreme İstatistikleri — Backend Analiz Raporu (v1 — İlk İnceleme)

**Tarih:** 2026-05-31
**Kapsam:** `stat_suru_ozet` v2 (cycle-bazlı) + `v_ureme_dongusu` view + frontend render
**Yöntem:** Kod incelemesi + canlı DB üzerinde doğrulama sorguları

---

## 1. Yönetici Özeti (v1 — Revize edildi)

Cycle-bazlı istatistik sisteminde tespit edilen ve sonradan **algoritmanın doğru olduğu anlaşılan** bulgular:

| # | Sorun | Şiddet | Sonuç |
|---|-------|--------|-------|
| 1 | **Sperma attribution bias'ı** | ~~Kritik~~ | Algoritma doğru. Repeat'ler bilinçli düşülüyor, cycle bazlı sperma sayımı doğru |
| 2 | **Düve sınıflandırması** | 🟢 Doğru | 10 düve, 8 Boş — sayılar tutarlı, sınıflandırma doğru |
| 3 | **Cycle vs Hayvan farkı** | 🟡 Yanıltıcı | %74.7 vs %66.1 farkı "Son Dönem" filtresinin doğal sonucu |
| 4 | **Bekliyor cycle'lar** | 🟠 Veri girişi | 247 günlük Bekliyor kaydı var; algoritma sorunu değil |
| 5 | **Tohumlamasız hayvanlar** | 🟡 Eksik payda | 16 dişi (10 düve + 6 inek) tohumlama kaydı olmadığı için hesap dışı |
| 6 | **Seed data şüpheli Boş'lar** | 🔴 Veri kalitesi | 18 son dönem Boş'tan 16'sı sadece seed data, onay log'u yok |

---

## 2. Metodoloji

### İncelenen Bileşenler

```
v_ureme_dongusu (view)          → Cycle tespiti + sonuç belirleme + sperma attribution
  └── stat_suru_ozet v2 (RPC)  → Son Dönem filtresi + hayvan/cycle aggregasyonu
       └── js/ui.js (render)   → Frontend gösterim
```

### Veri Kaynakları
- `supabase/migrations/20260530210000_v_ureme_dongusu.sql`
- `supabase/migrations/20260530220000_stat_suru_ozet_v2.sql`
- `supabase/migrations/99999999999999_ground_truth.sql` (canonical)
- Canlı DB üzerinde 15+ doğrulama sorgusu

---

## 3. Bulgular

### 3.1 Armada Red %100 — Analiz (SONUÇ: Algoritma Doğru)

**Gösterilen:** 20/20 cycle başarılı (%100)
**Canlı DB:** 24/24 cycle (`son_sperma = 'armada red'` olan tüm cycle'lar Gebe)

#### İlk Değerlendirme (Hatalı)

Armada Red'in ham tohumlama tablosundaki dağılımı:
- Toplam 62 deneme: 38 Boş + 24 Gebe
- 38 başarısız denemenin 22'si ara deneme → başka sperma gebe bırakmış
- "Gerçek başarı oranı: 24/62 = %38.7" ← **bu yanlış yorumlandı**

#### Doğru Değerlendirme

Sistem her cycle için **1 sperma** sayar. Repeat'ler bilinçli olarak düşülür:
- Başarılı cycle → `gebe_sperma` (gebe bırakan)
- Başarısız cycle → `son_sperma` (en son deneme)

100 cycle'da 110 sperma kullanılsa, repeat'ler düşülünce 100 sperma kalır. 55'i gebelik → %55. Bu doğru hesaplamadır. Repeat breeding denemeleri "başarısız cycle" değil, "başarılı cycle'a giden ara adımlar"dır.

Armada Red 24/24 çünkü Armada Red'in son sperma olduğu tüm cycle'lar gebe. Bu bir "survivorship bias" değil, tasarım tercihidir ve doğrudur.

### 3.2 Düve %20 — Sınıflandırma Doğru

**Gösterilen:** 2/10 gebe (%20)

Düve sınıflandırma mantığı:
```sql
WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
-- + NOT EXISTS dogum kontrolü (demografide)
```

10 düvenin tamamı `cycle_no = 1` → daha önce doğum yapmamış. 2 Gebe düve "Gebe Düve" grubunda, 8 Boş düve "Düve (Büyük)" grubunda. Sınıflandırma doğru.

### 3.3 Cycle %74.7 vs Hayvan %66.1 — Farkın Analizi

Son dönemdeki hayvan-cycle ilişkisi:
- Tek cycle'lı hayvan: 52
- Multi cycle'lı hayvan: 21
- **Önce Gebe sonra Boş (aynı dönemde): 10 hayvan**

Bu 10 hayvan iki metrik arasındaki farkın ana kaynağı. Matematiksel olarak tutarlı.

### 3.4 Bekliyor Cycle'lar

11 Bekliyor cycle tespit edildi. En kritikleri:
- **194 (e14f4fb6):** 247 gün — Eylül 2025'ten beri Bekliyor
- **195 (bac3b8f8):** 72 gün — Mart 2026'dan beri

194'ün tohumlama geçmişi:
```
Cycle 1: Ağu 2024 → Crowntown → Doğum Yaptı
Cycle 2: Eyl 2025 → Starred → Boş
          Eki 2025 → Starred → Boş
          May 2026 → Fresh → Bekliyor (3. deneme)
```

### 3.5 Son Dönem Filtresi — Mantık Değerlendirmesi

```sql
NOT EXISTS (
  SELECT 1 FROM v_ureme_dongusu v2
  WHERE v2.hayvan_id = v.hayvan_id
    AND v2.cycle_no > v.cycle_no
    AND v2.sonuc IN ('Gebe','Doğum Yaptı')
)
```

"Son gebelikten sonraki tüm cycle'lar + son gebeliğin kendisi". Davranış doğru.

### 3.6 Tohumlama Kaydı Olmayan Hayvanlar

| Kategori | Tohumlamalı | Tohumlamasız | Toplam |
|----------|------------|-------------|--------|
| Düve | 10 | 10 | 20 |
| İnek | 63 | 6 | 69 |

16 dişi hiç tohumlama kaydı olmadığı için istatistik dışı.

### 3.7 Seed Data Kaynağı

- 244/245 tohumlama kaydı seed data (9 Mayıs 2026 toplu import)
- Script/API üzerinden girilmiş (payload=null, kullanici_notu=null)
- Son dönemdeki 18 Boş'tan 16'sı şüpheli (onay log'u yok)

---

## 4. Matematiksel Tutarlılık Kontrolü

| Filtre | Gebe | Boş | Abort | Bekliyor | Toplam |
|--------|------|-----|-------|----------|--------|
| Son Dönem | 62 | 20 | 1 | 11 | 94 |
| Filtre Dışı | 33 | 0 | 0 | 0 | 33 |
| **Toplam** | **95** | **20** | **1** | **11** | **127** |

---

## 5. Çözüm Önerileri (v1)

### 5.1 ~~Sperma Attribution Modeli~~ → Algoritma doğru, değişiklik gerekmez

Repeat'ler bilinçli düşülüyor. Cycle bazlı sperma başarı oranı doğru hesaplanıyor.

### 5.2 Bekliyor Cycle'lar

60+ gün Bekliyor durumunda kalan cycle'lar için dashboard'da uyarı.

### 5.3 Seed Data Temizliği

16 şüpheli Boş cycle'ın gerçek durumu tespit edilip güncellenmeli.

### 5.4 UI İyileştirmeleri

- Dashboard'a tohumlanmamış hayvan sayısı ekle
- Sperma kartında Bekliyor sayısını göster
- "Hayvan Bazlı Sonuç" → "Hayvan Durumu"

---

## 6. Revizyon Notu

Bu raporun v1 versiyonunda "Armada Red %100 = survivorship bias, kritik hata" denmişti. Kullanıcı ile yapılan görüşme sonucunda:

- Repeat breeding denemelerinin cycle bazlı istatistikte sayılmaması **doğru tasarım**
- "Hayvanı gebe bırakan son spermadır, repeat'ler başarısızlık değil ara adımdır"
- Algoritma beklenen şekilde çalışıyor
- Asıl sorun algoritma değil, seed data'daki şüpheli veri girişleri

Güncel ve doğru analiz için: `ureme-istatistik-analiz-2026-05-31.md`
