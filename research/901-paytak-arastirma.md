# Küpe 901 / PAYTAK — SURU-TAKIP Araştırması
**Tarih:** 2026-06-04

## EgeSüt ERP — 901 Durumu

| Alan | Değer |
|------|-------|
| Küpe No | **901** |
| Devlet Küpe | `null` (kayıtlı değil) |
| Grup | Sağmal (Laktasyonda) — sessiz listede |
| Padok | Sağmal Padok |
| Tohumlama Durumu | `null` (hiç tohumlanmamış görünüyor) |
| Tohumlama Kaydı | **0** (hiç yok) |

## SURU-TAKIP — Eşleşen Kayıtlar

SURU-TAKIP'te 901 ile ilgili **4 farklı küpe_no** formatında toplam **20 kayıt** bulundu:

---

### 1. `PAYTAKTıRNAK` (8 kayıt) — ⭐ Direkt eşleşme

Kullanıcının verdiği isimlerle birebir örtüşüyor. 4 snapshot'ta da tutarlı.

| Tarih | Sperma | Gebelik | 4 Snapshot |
|-------|--------|---------|------------|
| **2025-07-08** | Fresco Red noncorn | Jdeıeııek | Holstein | ✅ **GEBE** | Hepsi gebe ✅ |
| **2025-06-08** | Armada red | 09856565 | Holstein | ❌ **Boş** | Hepsi boş ❌ |

> **2 tohumlama**: İlki boş (Haziran), ikincisi gebe (Temmuz). Gebelik tüm snapshot'larda doğrulanmış ✅

---

### 2. `TR092685901` (4 kayıt)

Devlet küpe no'su 901 ile bitiyor (`...85901`). EgeSüt'te devlet küpe null, ama numara eşleşiyor.

| Tarih | Sperma | Gebelik |
|-------|--------|---------|
| **2024-01-29** | Naika red | Naika red | Holstein | ✅ **GEBE** (tüm snapshot'lar) |

---

### 3. `156---TR092685901` (4 kayıt)

Aynı TR numarası (`TR092685901`), başında `156---` ön eki var. Muhtemelen **aynı hayvanın farklı kaydı**.

| Tarih | Sperma | Gebelik |
|-------|--------|---------|
| **2025-01-04** | Benim arkasaşlar | Hs62526 | Holstein | ✅ **GEBE** (tüm snapshot'lar) |

---

### 4. `TR092755901` (4 kayıt)

Farklı bir TR numarası (`TR092755901`), yine 901 ile bitiyor. **Bu farklı bir hayvan olabilir** — TR numarası farklı.

| Tarih | Sperma | Gebelik |
|-------|--------|---------|
| **2023-09-26** | Erice | 140815 | Holstein | ✅ **GEBE** (tüm snapshot'lar) |

---

## Eşleştirme Analizi

```
SURU-TAKIP                        →   EgeSüt
────────────────────────────────────────────────────
PAYTAKTıRNAK (2 tohum)            →   901 ✅ (isim eşleşmesi)
TR092685901 (1 tohum, 2024)       →   901 ⚠️ (son 3 hane 901)
156---TR092685901 (1 tohum, 2025) →   901 ⚠️ (aynı TR numarası, öncekiyle aynı hayvan)
TR092755901 (1 tohum, 2023)       →   ? ❌ (farklı TR numarası, farklı hayvan olabilir)
```

**Olasılık:** SURU-TAKIP'teki ilk 3 grup (`PAYTAKTıRNAK`, `TR092685901`, `156---TR092685901`) muhtemelen **aynı hayvan** (EgeSüt 901). `TR092755901` ise **farklı bir hayvan** (başka bir ineğin devlet küpe no'su).

## Toplam — EgeSüt 901'e Eklenebilecek Kayıtlar

EgeSüt 901'de hiç tohumlama kaydı yok. SURU-TAKIP'ten aktarılacak olası kayıtlar:

| Tarih | Sperma | Sonuç | Güvenilirlik |
|-------|--------|-------|------------|
| 2024-01-29 | Naika red | GEBE ✅ | 🔵 Orta (farklı TR no, ama eşleşebilir) |
| 2025-01-04 | Benim arkasaşlar | Hs62526 | Holstein | GEBE ✅ | 🟢 Yüksek (PAYTAKTıRNAK ile aynı TR) |
| 2025-06-08 | Armada red | 09856565 | Holstein | Boş ❌ | 🟡 Orta (güvenilmez boş) |
| 2025-07-08 | Fresco Red noncorn | GEBE ✅ | 🟢 Yüksek (ismen eşleşiyor ✅) |

> ⚠️ `TR092755901` kaydı (2023-09-26) **dahil edilmemeli** — farklı bir hayvanın devlet küpe numarası.
