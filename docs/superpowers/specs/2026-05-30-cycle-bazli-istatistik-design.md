# Cycle-Bazlı İstatistik Tasarımı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tohumlama istatistiklerini record-bazlı sayımdan cycle-bazlı + hayvan-bazlı sentez modeline geçirmek.

**Architecture:** PostgreSQL view (`v_ureme_dongusu`) cycle detection yapar, `stat_suru_ozet` RPC bu view'dan iki seviyeli aggregation üretir (cycle→hayvan, hayvan→sürü). Frontend mevcut stat kartını yeni formata adapte eder.

**Tech Stack:** PostgreSQL (view + RPC), Vanilla JS (ui.js)

---

## Problem

Mevcut `stat_suru_ozet` RPC her tohumlama kaydını bağımsız birim olarak sayıyor. Bu şu anomalilere yol açıyor:

1. **Şişirilmiş denominator:** 73 hayvanın 234 kaydı var → hayvan başı 3.2 kayıt. Gebelik oranı yapay düşük görünüyor.
2. **Repeat breeding çift sayımı:** Bir cycle'da 3 kez tohumlanan hayvan = 3 ayrı başarısızlık. Gerçekte 1 cycle henüz sonuçlanmamış.
3. **Bekliyor kayıtlar:** `toplam`'dan çıkarılsa da aynı cycle'daki Boş kayıtlarla birlikte sayılarak cycle sonucunu bulanıklaştırıyor.
4. **Sperma attribution yanlış:** Cycle'da 3 farklı sperma kullanılınca üçü de başarısız sayılıyor. Gerçekte son sperma ile gebe kaldıysa kredi o sperma'nın.

## Çözüm: İki Katmanlı Sentez

### Katman 1: `v_ureme_dongusu` View

Her satır = 1 üreme döngüsü (cycle).

**Cycle sınırı:** `deneme_no = 1` yeni cycle başlatır. Mevcut üreme sekmesindeki "tekrar aşım" mantığıyla uyumlu — repeat aşımlarda `deneme_no` artıyor (2, 3...), yeni cycle'da 1'e dönüyor.

**Kolonlar:**

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| hayvan_id | uuid | |
| padok | text | Hayvanın padoğu |
| durum | text | Hayvan durumu (Aktif/Pasif) |
| kategori | text | Düve / İnek / Bilinmiyor |
| cycle_no | int | Hayvan bazında cycle numarası (1, 2, 3...) |
| baslangic | date | Cycle'daki ilk tohumlama tarihi |
| bitis | date | Cycle'daki son tohumlama tarihi |
| deneme_sayisi | int | Cycle içi toplam tohumlama sayısı |
| sonuc | text | Cycle sonucu: Gebe / Boş / Abort / Bekliyor |
| gebe_sperma | text | Başarılı cycle'da Gebe kaydındaki sperma (normalize) |
| son_sperma | text | Son kullanılan sperma (başarısız/devam eden cycle'lar için) |

**Cycle sonucu belirleme önceliği:**
1. Herhangi bir kayıt Gebe/Doğum Yaptı → cycle sonucu = **Gebe**
2. Herhangi bir kayıt Abort → cycle sonucu = **Abort**
3. Herhangi bir kayıt Bekliyor → cycle sonucu = **Bekliyor** (devam ediyor)
4. Tümü Boş → cycle sonucu = **Boş**

### Katman 2: `stat_suru_ozet` RPC Yeniden Yazımı

View'dan sorgulayarak iki seviyeli çıktı üretir.

**Parametreler:** Aynı kalır: `p_padok text, p_son_donem boolean DEFAULT true`

**Son Dönem mantığı:** View'daki cycle'lardan sadece son tamamlanan cycle sonrasındakileri al. Mevcut `son_basari` CTE mantığı cycle seviyesinde uygulanır.

**Çıktı formatı:**

```json
{
  "hayvan": { ... },  // mevcut hayvan demografisi — değişmez
  "gebelik": {
    "hayvan_ozet": {
      "toplam": 62,
      "gebe": 41,
      "bos": 21,
      "devam_eden": 11,
      "oran": 66.1
    },
    "cycle_ozet": {
      "toplam_cycle": 95,
      "basarili": 41,
      "basarisiz": 43,
      "devam_eden": 11,
      "oran": 48.8,
      "ort_deneme": 1.8
    },
    "kategori": [
      {"ad": "İnek", "hayvan_toplam": 52, "hayvan_gebe": 39, "hayvan_oran": 75.0,
       "cycle_toplam": 85, "cycle_basarili": 39, "cycle_oran": 45.9},
      {"ad": "Düve", "hayvan_toplam": 10, "hayvan_gebe": 2, "hayvan_oran": 20.0,
       "cycle_toplam": 10, "cycle_basarili": 2, "cycle_oran": 20.0}
    ],
    "sperma_top5": [
      {"ad": "starred", "cycle_toplam": 30, "cycle_basarili": 20, "cycle_oran": 66.7}
    ],
    "deneme": [
      {"no": 1, "gebe": 25, "toplam": 60, "oran": 41.7},
      {"no": 2, "gebe": 10, "toplam": 25, "oran": 40.0},
      {"no": 3, "gebe": 6, "toplam": 10, "oran": 60.0}
    ]
  }
}
```

**Açıklamalar:**

- `hayvan_ozet.toplam`: En az 1 tamamlanmış cycle'ı olan distinct hayvan sayısı. `devam_eden` hariç.
- `hayvan_ozet.oran`: `gebe / (gebe + bos)` — sadece tamamlanmış cycle'lar. Bekliyor/devam eden dahil değil.
- `cycle_ozet.toplam_cycle`: Tamamlanmış cycle sayısı (Gebe + Boş + Abort). Bekliyor hariç.
- `cycle_ozet.oran`: `basarili / (basarili + basarisiz)` — abort dahil değil.
- `cycle_ozet.ort_deneme`: Başarılı cycle'larda ortalama deneme sayısı.
- `sperma_top5`: Cycle bazlı. Başarılı cycle'da `gebe_sperma`'ya kredi, başarısız cycle'da `son_sperma` atfedilir. Minimum 3 cycle'lık sperma'lar dahil.
- `deneme`: `deneme_sayisi` bazlı dağılım — "1 denemede gebe kalanlar", "2 denemede gebe kalanlar" vs. Sadece tamamlanmış cycle'lar.
- `kategori`: Her kategori hem hayvan bazlı hem cycle bazlı oranları içerir.

### Katman 3: Frontend Adaptasyonu (ui.js)

Mevcut stat kartı yapısı korunur. Değişiklikler:

1. **Özet satırı:** `"🐄 41/62 gebe (%66) · 95 cycle · ort 1.8 deneme"` formatına geçer
2. **Hayvan vs Cycle toggle yok** — ikisi aynı kartta gösterilir (sentez)
3. **Bekleyen bilgi satırı:** `"⏳ 11 hayvan sonuç bekliyor"` — hesaba dahil değil
4. **Sperma/kategori/deneme accordion'ları:** Cycle bazlı verilerle güncellenir
5. **Son Dönem / Tüm Zamanlar toggle:** Aynen kalır

### Mevcut stat_gebelik_ozet RPC

`stat_gebelik_ozet` RPC'si tarih aralığı filtreli versiyondur. Bu RPC de aynı view'dan beslenecek şekilde güncellenecek. Parametreleri aynı kalır (`p_donem_baslangic`, `p_donem_bitis`, `p_kategori`, `p_grup`, `p_sperma`).

## Kapsam Dışı

- Materialized view / trigger (234 kayıt için gereksiz)
- Yeni UI sekmesi (mevcut stat kartı adapte edilir)
- Sperma master tablo (ayrı iş — alfa-istatistik.md Faz 2)
- Tarih aralığı filtresi UI (Seçenek 3 — ayrı iş)
- Hekim performansı (alfa-istatistik.md'de not edildi)

## Risk

| Risk | Etki | Önlem |
|------|------|-------|
| `deneme_no` güvenilmez/tutarsız | Cycle sınırları yanlış çıkar | View'ı canlı veriyle test et, edge case'leri kontrol et |
| Mevcut UI'ın beklediği format değişiyor | Stat kartı bozulur | RPC çıktısını önce kontrol et, UI'ı sonra adapte et |
| Son Dönem cycle filtresi karmaşıklaşır | Yanlış cycle'lar dahil/hariç olur | View seviyesinde `son_donem` filtresi test et |
