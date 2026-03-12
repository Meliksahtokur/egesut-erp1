# EgeSüt ERP — SPEC v12
> Operasyonel rehber. Mimari kararlar → ARCHITECTURE.md
> Son güncelleme: 2026-03-12

---

## 0. OTURUM PROTOKOLÜ

1. SPEC'i oku → sıradaki item'ı söyle → onay al → başla
2. Değişiklik formatı: SEARCH/REPLACE veya inline python. Tam dosya sadece büyük refactor'da.
3. Migration her zaman idempotent. Yeni tablo = RLS + SECURITY DEFINER.
4. Oturum sonu SPEC güncelle, push et.

---

## 1. MEVCUT DURUM

- Migration 022 ✅ uygulandı
- Migration 023 ✅ uygulandı (`remove_drug_administration`)
- Migration 024 ✅ uygulandı (`link_drug_to_stock`)

---

## 2. SPRINT — SIRADAKI GÖREVLER

### ✅ Tamamlanan
| Item | Açıklama |
|------|----------|
| **CLN-01** | Migration 022 Supabase'e uygulandı |
| **CLN-02** | `m-case` modal HTML'e eklendi, `diseases` dropdown DB'den, `create_case()` RPC bağlandı, `openMWithHayvan` + `acMap` güncellendi |
| **CLN-03** | Vaka detay UI tamamlandı. Eksik `remove_drug_administration` RPC → Migration 023 |
| **CLN-04** | `drugs` ↔ `stok` bağlama: Migration 024 + Ayarlar'a bölüm + `renderDrugStokList` + `submitDrugStokLink` |
| **CLN-05** | Hayvan kartı: `activeCases` IDB'den çekildi, chip `cases` tablosuna bakıyor, tab-saglik'te aktif vakalar tıklanabilir chip |

### 🔴 Şu An Yapılacak
| Item | Açıklama | Dosyalar |
|------|----------|----------|
| **VAC-01** | Aşılama modülü (vaccines tablosu + protokol + görev) | migration, ui.js, forms.js |

### 🟡 Sonraki Sprint
| Item | Açıklama |
|------|----------|
| BULK-01 | Toplu işlem paneli |
| S2-05 | Abort akışı |
| S2-07 | Görev renk mantığı (geciken/bugün/yakın/gelecek) |
| S2-09 | Excel import/export |
| S2-10 | Grup/padok/laktasyon yeniden tasarımı + mig-015 |

### ⏸ Bloke / Bekleyen
| Item | Bloke Sebebi |
|------|-------------|
| T-07 İlaç yönetimi (eski sistem) | CLN serisi tamamlandı — re-evaluate |
| S3-01 Supabase Realtime | Sprint 3 |
| DEBT-01 Teknik borç temizliği (orphan kolonlar, drift) | Sprint 3 |

---

## 3. TEKNİK REFERANS

### Geliştirme Pipeline
```bash
# SEARCH/REPLACE (standart)
cat > /tmp/r.txt << 'EOF'
SEARCH:
eski metin
REPLACE:
yeni metin
