# farmOS — Üreme Veri Modeli Analizi

**Kaynaklar:**
- https://farmos.org/model/type/asset/
- https://farmos.org/model/type/log/
- https://docs.farmos.org
- https://github.com/farmOS/farmOS
- https://www.drupal.org/project/farm/issues/2402771 (Breeding log type)

---

## Animal Asset Structure

farmOS hayvanları **Asset** (Varlık) olarak modeller. Tüm varlık tipleri:
- Land (Arazi)
- Plant (Bitki)
- **Animal (Hayvan)**
- Equipment (Ekipman)
- Compost, Structure, Sensor, Water, Material, Group*

**Group Asset:** Diğer Asset'leri "grup üyesi" olarak içerebilir. Tipik kullanım: **sürü (herd)** temsili. Grup üyelik değişiklikleri Log'lar ile kaydedilir → zaman içinde hangi hayvanın hangi grupta olduğu izlenebilir.

**Standart Asset alanları:**
- `name` — zorunlu
- `flags` (Priority, Needs review, Monitor — modüller ekleyebilir)
- `geometry` — konum (konum logic'i ile hesaplanır, doğrudan editlenmez)
- `intrinsic_geometry` — sabit varlıklar için
- `is_location` / `is_fixed`
- `notes`
- `ID tags`
- `data` (esnek JSON)
- `archived`

**Asset-Log ilişkisi:** Asset'ler az bilgi taşır. Değerli **tarihsel** bilgiler Asset'e referans veren **Log**'larda saklanır.

---

## Breeding Log Structure

farmOS'ta tüm olaylar **Log** olarak modellenir. Log tipleri modüller tarafından tanımlanır:

Temel Log tipleri:
- Activity (Aktivite)
- Observation (Gözlem)
- Input (Girdi — gübre, ilaç vb.)
- Harvest (Hasat)
- **Medical** (Tıbbi — aşı, tedavi)

**Breeding Log tipi** (Drupal.org issue #2402771):
- `date` — tarih
- `female_animal` — dişi hayvan referansı (zorunlu)
- `male_animal` — erkek hayvan referansı (opsiyonel, suni tohumlama notlarda belirtilir)
- `notes` — notlar

> Tohumlama olayları hayvandan **bağımsız birer Log** olarak tasarlanır, sonra hayvana bağlanır. Bu, olay-merkezli (event-sourcing) bir mimaridir.

**Log-Category ilişkisi:** Bir Log birden çok kategoriye ait olabilir. Kategoriler dinamik değişebilir. Bu, "bu tohumlama hem üreme hem sağlık kategorisinde" gibi esnek sınıflandırma sağlar.

**Location Logic:** Hayvan hareketleri (padok değişimi) **movement Log**'ları ile kaydedilir. Asset'in geometry'si, hareket log'larından **hesaplanır** (doğrudan yazılmaz).

---

## Group/Movement Tracking

```
Group Asset "Sağmal Sürü"
  ├── Animal A (üye)
  ├── Animal B (üye)
  └── Animal C (2024-01 → 2024-06 arası üyeydi)
```

Grup üyeliği değişiklikleri Log ile kaydedilir → **tam zaman damgalı geçmiş** tutulur. Bizim projeye uyarlanırsa: padok değişimleri `islem_log` benzeri bir yapıda izlenebilir.

---

## Key Takeaways for Our Project

| farmOS Pattern | Bizim Projeye Uyarlama |
|---------------|----------------------|
| Asset-Log ayrımı | `hayvanlar` tablosu minimal, olaylar `tohumlama`/`dogum`/`islem_log`'da |
| Group Asset = sürü | `grup_padok` yapımız benzer |
| Log ile hareket takibi | `islem_log` ile padok değişimi zaten yapılıyor |
| Log-Category esnekliği | Bizim `islem_log.islem_tipi` birebir karşılıyor |
| Breeding → ayrı Log tipi | `tohumlama` tablomuz bunun PostgreSQL karşılığı |
| Hesaplanan geometry | Bizim `v_ureme_dongusu` gibi computed view'lar aynı felsefe |
