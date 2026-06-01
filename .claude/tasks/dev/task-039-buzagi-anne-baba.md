# TASK-039 — Buzağı Anne-Baba Bağlantısı

**Durum:** ⏳ BEKLEYEN  
**Öncelik:** Orta  
**Tarih:** 2026-05-27

---

## Problem

Buzağı kaydedilirken anne (inek) bilgisi var ancak baba (boğa/sperma) bağlantısı kurulmuyor. Tohumlama kaydından baba bilgisi otomatik çekilmeli veya manuel girilmeli.

---

## Beklenen Davranış

- Buzağı doğum kaydında anne → ilgili son tohumlama kaydından baba bilgisi otomatik doldurulsun
- Buzağı profilinde anne ve baba görünsün
- Soy ağacı için FK bağlantısı kurulsun (anne_id, baba_id kolonları)

---

## Notlar

- `hayvanlar` tablosunda `anne_id`, `baba_id` kolonları mevcut mu kontrol et
- Tohumlama → doğum → buzağı zinciri üzerinden baba bilgisi çekilebilir
