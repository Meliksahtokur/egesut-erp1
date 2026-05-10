# Spec: Aşı Rapel Otomasyonu + Yönetimi

**Tarih:** 2026-05-10
**Öncelik:** YÜKSEK
**Bağımlılık:** gorev-sistemi-iyilestirme spec'i ile paralel yapılabilir

---

## Mevcut Durum

- `vaccines` tablosu: `repeat_interval_days` kolonu VAR (365, 180, null)
- `add_vaccination` RPC: `repeat_interval_days` varsa `next_due_date` hesaplıyor → `vaccination_log.next_due_date`
- AMA: `next_due_date` bir görev oluşturmuyor, sadece bilgi olarak duruyor
- İleri gebe aşı: trigger ile görev yaratılıyor (240/260/265 gün)
- Buzağı aşıları: HİÇBİR otomasyon yok
- İlk kez uygulanan aşılarda rapel: yok

---

## Hedef

1. Herhangi bir aşı yapıldığında, `repeat_interval_days` varsa → otomatik rapel **görevi** oluşsun
2. Rapel süresi kullanıcı tarafından ayarlanabilir olsun (vaccines tablosundaki `repeat_interval_days`)
3. Buzağı aşı takvimi: doğumdan itibaren günlere göre otomatik görev

---

## 1. Genel Aşı Rapeli (add_vaccination tetiklemeli)

### Mevcut `add_vaccination` RPC akışı:
```
vaccination yapılır → stok düşer → next_due_date hesaplanır → biter
```

### Yeni akış:
```
vaccination yapılır → stok düşer → next_due_date hesaplanır →
  IF repeat_interval_days IS NOT NULL THEN
    gorev_log INSERT (gorev_tipi='ASI_RAPEL', hedef_tarih=next_due_date, stok_id, hayvan_id)
  END IF
```

### Migration: `add_vaccination` RPC güncelle

```sql
-- Mevcut RPC'nin sonuna ekle (vaccination başarılı olduktan sonra):
IF v_vaccine.repeat_interval_days IS NOT NULL THEN
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak)
  VALUES (
    gen_random_uuid(),
    p_animal_id::uuid,
    'ASI_RAPEL',
    '💉 ' || v_vaccine.name || ' (rapel)',
    v_next_due,
    false,
    v_vaccine.stock_item_id,
    1,
    'ASI_RAPEL'
  )
  ON CONFLICT DO NOTHING;
END IF;
```

### Kısıtlar
- `ILERI_GEBE_ASI` görevinden yapılan aşılarda bu tetiklenmemeli (çünkü `ileri_gebe_asi_tamamla` RPC kendi rapelini zaten yaratıyor)
- Not: `add_vaccination` RPC'de `p_notes` parametresi var → "GorevID:" prefix varsa ileri gebe, yoksa normal aşı
- Duplicate kontrolü: aynı hayvan + aynı aşı + aynı hedef_tarih varsa insert etme

---

## 2. Rapel Süresi Yönetimi (Ayarlar)

### Mevcut Durum
- Ayarlar panelinde "Aşı Kataloğu" bölümü var (sadece liste, düzenlenemiyor)
- `vaccines.repeat_interval_days` → backend'de var, UI'dan değiştirilemez

### Hedef
- Ayarlar → Aşı Kataloğu bölümünde her aşının yanında rapel süresi düzenlenebilir
- Dropdown: "Tek Doz" / "21 gün" / "90 gün" / "180 gün" / "365 gün" / "Özel (gün gir)"

### UI Tasarım
```
Aşı Kataloğu:
┌─────────────────────────────────────────┐
│ Şarbon Aşısı        [365 gün ▼] [Zorunlu]│
│ BVD Aşısı           [365 gün ▼] [Zorunlu]│
│ Rotavirus Aşısı     [Tek Doz  ▼]         │
│ ...                                       │
└───────────────────────────────────────────┘
```

### Implementasyon
- `vaccines` tablosu zaten var, `repeat_interval_days` UPDATE edilecek
- Ayarlar panelindeki aşı listesi render'ına select eklenir
- Değiştiğinde: `write('vaccines', {repeat_interval_days: val}, 'PATCH', 'id=eq.XXX')`

### Stok Ekleme Ekranı (m-stok-add)
- Yeni aşı stoku eklerken rapel süresi de sorulmalı
- Ama NOT: stok ve vaccine ayrı tablolar. Stok eklenirken vaccine kaydı var mı kontrol → varsa repeat_interval göster

---

## 3. Buzağı Aşı Takvimi (Opsiyonel — İkinci Faz)

### Konsept
- Doğum kaydı yapıldığında buzağıya otomatik aşı görevleri oluşsun
- Hangi aşı hangi günde → `vaccination_schedule` tablosu (varsa)

### Mevcut Tablo Kontrol
`vaccination_schedule` tablosu mevcut mu kontrol edilecek. Eğer yoksa:

```sql
CREATE TABLE vaccination_schedule (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  vaccine_id uuid REFERENCES vaccines(id),
  hedef_gun integer NOT NULL, -- doğumdan itibaren gün
  hayvan_tipi text DEFAULT 'buzagi', -- buzagi, duve, inek
  aciklama text,
  aktif boolean DEFAULT true
);
```

### Trigger: `trg_dogum_buzagi_asi`
Doğum kaydı eklenince → `vaccination_schedule` tablosundaki aktif kayıtlara göre gorev_log'a görevler ekle.

### NOT
Bu kısım ayrı bir spec olarak da yazılabilir. Kullanıcının buzağı aşı ihtiyacı netleşince detaylandırılır.

---

## Test Senaryosu

1. Normal aşı yap (Şarbon gibi repeat_interval=365) → gorev_log'da 1 yıl sonraki rapel görevi oluşmalı
2. Tek doz aşı yap (Rotavirus, null) → rapel oluşmamalı
3. Ayarlar → Aşı Kataloğu → Şarbon'un rapel süresini 180'e çevir → yeni aşılar 180 gün rapel alsın
4. İleri gebe aşı (RPC ile) → duplicate rapel oluşmamalı
