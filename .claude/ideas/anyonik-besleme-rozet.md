# Anyonik Besleme — "Beslendi" Rozeti (⚠️ liste)

**Tarih:** 2026-06-26
**Durum:** Fikir — implemente edilmedi
**Öncelik:** Düşük — UX netliği, bug değil
**Tahmini efor:** 1 oturum (sadece ui.js dashboard ⚠️ Anyonik render)

---

## Problem

Dashboard ⚠️ Anyonik listesi = anyonik beslemeye **uygun tüm hayvanlar** (gebelik gününe göre).
BESLEME görev kartları = o gün **açık (yapılmamış)** öğünler.

Bir hayvan ⚠️'de görünüp besleme kartı çıkmayabilir → çünkü o günkü besleme **zaten tamamlanmış**.
Bu doğru davranış ama kullanıcıda "görev eksik mi?" kafa karışıklığı yaratıyor (2026-06-26'da yaşandı,
002/136/184'ün sabah+akşam'ı bitmişti → kart yok → "eksik" sanıldı).

## Çözüm: tik rozeti

⚠️ Anyonik listesindeki her hayvanın yanına o günkü besleme durumunu göster:

- **1 tik (✓):** sabah beslendi (akşam açık)
- **2 tik (✓✓):** sabah + akşam beslendi (gün tamam)
- **tik yok:** henüz beslenmedi

Veri kaynağı: o hayvanın `gorev_tipi='BESLEME'`, `hedef_tarih=bugün` görevlerinin
sabah/akşam `tamamlandi` durumu (aciklama'da "Sabah"/"Akşam").

## Not

Bu rozet, ⚠️ uygunluk-listesi ile açık-görev-kartı ayrımını görsel olarak kapatır →
"demedi deme" sınıfı karışıklıkları önler.
