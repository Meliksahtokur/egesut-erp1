# Kural Motoru (Rule Engine) — Gelecek Fikir

**Oluşturuldu:** 2026-05-21  
**Durum:** Fikir — şu aşama için overkill, erken optimizasyon  
**Bağlam:** Anyonik besleme ihtiyacından türedi, kurumsal satış hedefi için ileride değerli olabilir

---

## Neden Şimdi Değil

- Mevcut protokol sayısı 3-4 (hardcode RPC ile yönetilebilir)
- Rule engine debug'ı zor: "neden bu hayvana görev oluşmadı?" sorusu karmaşıklaşır
- Yanlış filtre → 200 gereksiz görev riski
- Aynı ihtiyaç ~1.5 saatte RPC'ye satır ekleyerek çözülüyor
- Protokol sayısı 6-7'ye ulaşınca pattern zaten emerge eder

## Ne Zaman Yapılır

Farklı çiftlik konfigürasyonları, 10+ farklı protokol, çok kullanıcılı yapı gerektiğinde. Kurumsal satış aşamasında "protokol şablonları" modülü olarak konumlandırılabilir.

---

## Mimari Tasarım

### Temel Kavramlar

```
kural → kural_tara() → gorev_log (kural_id ile bağlı)
```

- `kural` = şablon (ne, ne zaman, kime, kaç sıklıkta)
- `kural_tara()` = scanner RPC, app sync'te çalışır  
- `gorev_log` = sadece `kural_id` kolonu eklenir (minimal müdahale)

### DB Şeması

#### Yeni tablo: `kural`

| Kolon | Tip | Açıklama |
|---|---|---|
| `id` | uuid PK | |
| `baslik` | text | "Buzağı Boynuz Yakma" |
| `gorev_tipi` | text | SAGLIK / BAKIM / GENEL / custom |
| `aciklama` | text | |
| `hedef_tip` | text | `hayvan` `padok` `grup` `suru` `filtre` |
| `hedef_id` | text nullable | Spesifik hayvan/padok/grup id |
| `hedef_filtre` | jsonb nullable | `{"tur":"buzagi","min_yas_gun":25}` |
| `tetik_tip` | text | `yas_esik` `gebelik_gun` `takvim` `event` |
| `tetik_deger` | int nullable | 25 (gün), 260 (gebelik günü) |
| `tetik_event` | text nullable | `DOGUM` `GEBE` `SATIS` |
| `tekrar_tip` | text | `bir_kere` `gunluk` `periyodik` |
| `gunluk_adet` | int default 1 | Günde kaç kez (1=1x, 2=sabah+akşam) |
| `periyot_gun` | int nullable | Her N günde bir |
| `baslangic_tarih` | date nullable | |
| `bitis_tarih` | date nullable | |
| `bitis_kosul` | text nullable | `DOGUM` `ABORT` `SATIS` `OLUM` `YAS` |
| `bitis_deger` | int nullable | Örn. 60 gün yaşına gelince kapat |
| `durum` | text | `aktif` `pasif` `tamamlandi` |
| `son_tarama` | timestamptz | |

#### Yeni tablo: `kural_uretim_log` (dedup)

| Kolon | Açıklama |
|---|---|
| `kural_id` | FK → kural |
| `hayvan_id` | nullable |
| `tarih` | Hangi gün üretildi |
| `gorev_id` | FK → gorev_log |

#### Mevcut tabloya minimal ekleme

```sql
ALTER TABLE gorev_log ADD COLUMN kural_id uuid REFERENCES kural(id);
```

### Scanner: `kural_tara()` RPC

App sync sırasında çağrılır. Her aktif kural için:
1. `hedef_filtre`'ye göre hayvanları bulur  
2. `kural_uretim_log`'dan bugün üretildi mi kontrol eder  
3. Eksikler için `gorev_log` INSERT atar, `kural_id` bağlar  
4. `kural.son_tarama` günceller  
5. Bitiş koşulu dolmuşsa `kural.durum = 'tamamlandi'`  

### Desteklenen Kural Tipleri

| Örnek | tetik_tip | hedef_filtre | tekrar_tip |
|---|---|---|---|
| 25 gün buzağı → boynuz yak | `yas_esik` | `{"tur":"buzagi","min_yas_gun":25}` | `bir_kere` |
| 260 gün gebe → anyonik (doğuma kadar 2x/gün) | `gebelik_gun` | `{"sonuc":"Gebe","min_gebe_gun":260}` | `gunluk`, adet=2, bitis=DOGUM |
| Tüm padok → haftalık tırnak bakımı | `takvim` | — hedef_tip=padok | `periyodik` 7 gün |
| Spesifik hayvan → sabah akşam ilaç | `takvim` | — hedef_tip=hayvan | `gunluk` adet=2, bitis_tarih |

### UI Bileşenleri

Görevler sekmesine "Kurallar" sub-tab eklenir:
- Aktif kural listesi (son tarama, üretilen görev sayısı)
- Yeni Kural formu — 4 adımlı modal:
  1. **Ne?** → Başlık + görev tipi + açıklama
  2. **Kime?** → Hayvan / Padok / Grup / Filtre builder
  3. **Ne zaman?** → Tetikleyici (yaş / gebelik günü / takvim / event)
  4. **Sıklık & Bitiş** → Bir kere / Günlük N kez / Her N günde · Tarih veya event

Kural kaynaklı görevler regular task listesinde `🔄` ikonu ile görünür.

### Kurumsal Değer

Bu modül "Protokol Şablonları" olarak konumlandırılırsa:
- Çiftlik sahibi kendi domain protokollerini sisteme kodlar
- Farklı müşteri konfigürasyonları bir arayüzden yönetilir
- Çiftçi kendi işini yapar, ERP sadece takip eder
- Potansiyel: pre-built şablon kütüphanesi (veteriner onaylı protokoller)

---

## İlgili Dosyalar

- Mevcut pattern: `supabase/migrations/99999999999999_ground_truth.sql` → `ileri_gebe_gorev_kontrol`
- Görev render: `js/ui.js` → `renderTask()` / `loadTasks()`
- Görev tipleri: `gorev_log.gorev_tipi` — ILERI_GEBE, SAGLIK, BAKIM, GENEL, ASI_HATIRLATMA
