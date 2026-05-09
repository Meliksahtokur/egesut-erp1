# İleri Gebe Aşı Tamamlama + Rapel Otomasyonu — Spec
Tarih: 2026-05-09  
Kapsam: ILERI_GEBE_ASI görev tamamlama → vaccination_log + stok düşme + rapel otomasyonu

---

## Problem

`ileri_gebe_gorev_kontrol` RPC'nin oluşturduğu görevler `stok_id` ve `vaccine_id` içermiyor. Bu yüzden:
1. Görev tamamlandığında stok düşmüyor
2. Hayvan aşı geçmişine kayıt gitmiyor
3. Rapel (2. doz) görevi otomatik oluşmuyor

---

## Çözüm: Kombine RPC + Modal Genişletme

---

## Bölüm 1 — Veri Katmanı

### 1.1 `ileri_gebe_gorev_kontrol` RPC Güncelleme

**Dosya:** `supabase/migrations/20260509000001_ileri_gebe_gorev.sql` (veya yeni migration)

Rota-Corona görevi oluştururken:
```sql
-- Rota-Corona aşısını bul
SELECT v.id, v.stock_item_id
INTO v_vaccine_id, v_stok_id
FROM vaccines v
WHERE v.name ILIKE '%Rota%'
LIMIT 1;

-- Görevi stok_id ve miktar ile oluştur
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak)
VALUES (
  gen_random_uuid()::text,
  v_hayvan_id,
  'ILERI_GEBE_ASI',
  '💉 Rota-Corona Aşısı (1. doz)',
  (CURRENT_DATE + (v_gun_hedef - v_gun)::int),
  false,
  v_stok_id,
  1,
  'ILERI_GEBE'
)
-- Dedup: mevcut migration'daki WHERE NOT EXISTS mantığı korunur
-- (aynı hayvan_id + aciklama çifti yoksa ekle)
WHERE NOT EXISTS (
  SELECT 1 FROM gorev_log g
  WHERE g.hayvan_id = v_hayvan_id
    AND g.aciklama ILIKE '%Rota-Corona%1. doz%'
    AND g.tamamlandi = false
);
```

SC Ademin ve E Vitamini görevleri `gorev_tipi = 'ILERI_GEBE'` olarak kalır (ilaç, aşı değil).

### 1.2 Yeni RPC: `ileri_gebe_asi_tamamla`

**Dosya:** `supabase/migrations/20260509000002_ileri_gebe_asi_tamamla.sql`

```sql
CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  jsonb;
  v_rapel_id    text;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  -- 1. Görevi çek ve kontrol et
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  -- 2. Aşıyı kaydet (add_vaccination vaccination_log + stok trigger)
  SELECT public.add_vaccination(
    v_gorev.hayvan_id, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  -- 3. Görevi tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id;

  -- 4. 1. doz ise rapel görevi oluştur
  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    v_rapel_tarih := p_tarih + 21;
    v_rapel_id := gen_random_uuid()::text;
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
    VALUES (
      v_rapel_id,
      v_gorev.hayvan_id,
      'ILERI_GEBE_ASI',
      '💉 Rota-Corona Aşısı (2. doz)',
      v_rapel_tarih,
      false,
      v_gorev.stok_id,
      1,
      p_gorev_id,
      'ILERI_GEBE'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'rapel_gorev_id', v_rapel_id,
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;
```

---

## Bölüm 2 — Frontend: Task Detay Modalı

**Dosya:** `js/ui.js` (`openTaskDet`) + `index.html`

### 2.1 ILERI_GEBE_ASI Görev Tespiti

`openTaskDet()` içinde `t.gorev_tipi === 'ILERI_GEBE_ASI'` ise:
- Standart "Tamamla" butonu gizlenir
- Yerine "💉 Aşıyı Uygula" butonu gösterilir

### 2.2 Mini Form (modal içinde genişler)

"Aşıyı Uygula" butonuna tıklanınca `#td-asi-form` div açılır:

```
Aşı: [Rota-Corona Aşısı] (read-only, stok_id'den isim çözümlenir)
Tarih: [bugün] (date, max=bugün)
Doz: [X ml] (number, varsayılan vaccines tablosundan)
[Uygula ve Tamamla]  [İptal]
```

### 2.3 RPC Çağrısı ve Sonuç

`ileri_gebe_asi_tamamla(gorev_id, vaccine_id, tarih, doz)` çağrılır.

Başarı:
- Modal kapanır
- `updateTaskBadge()` çağrılır
- `loadDash()` çağrılır
- Toast: `"✅ Aşı kaydedildi · Rapel: {rapel_tarih}"`

Hata:
- Toast hata mesajı (Türkçe, `_trErr`)

### 2.4 Vaccine ID Çözümleme

`stok_id` → `vaccines` tablosunda `stock_item_id = stok_id` olan kayıt → `vaccine_id` ve `default_dose_ml`.

Frontend'de: `getData('vaccines').then(vs => vs.find(v => v.stock_item_id === t.stok_id))`.

---

## Bölüm 3 — Rapel Görev Tarihi Düzenleme

**Dosya:** `js/ui.js` (`openTaskDet`)

### 3.1 Rapel Görev Tespiti

`t.parent_id` varsa + `t.gorev_tipi === 'ILERI_GEBE_ASI'` → rapel görevidir.

### 3.2 Date Picker

`openTaskDet()` içinde rapel görevi tespit edilince parent task `getData('gorev_log', g => g.id === t.parent_id)` ile çekilir.

Parent görevin `tamamlanma_tarihi`'nden:
- `min = tamamlanma_tarihi + 14 gün`
- `max = tamamlanma_tarihi + 21 gün`

Modal içinde: `<input type="date" id="td-rapel-tarih" min="..." max="...">` + "📅 Tarihi Kaydet" butonu.

Kaydet → `write('gorev_log', {hedef_tarih: yeniTarih}, 'PATCH', 'id=eq.' + t.id)` → modal güncellenir, toast "📅 Rapel tarihi güncellendi".

---

## Bölüm 4 — 148 Numaralı Hayvan Düzeltmesi

148'in Rota-Corona aşısı fiziksel olarak yapıldı fakat sisteme kayıt girmedi. Spec tamamlandıktan sonra:
1. Yeni modal aracılığıyla görevi tamamla → vaccination_log + stok + rapel otomatik oluşur
2. Ya da direkt `add_vaccination` RPC ile manuel kayıt gir + stok hareketi ekle

---

## Kapsam Dışı

- SC Ademin, E Vitamini görevleri bu akışa dahil değil (ilaç, aşı değil — farklı kayıt sistemi)
- 2. dozdan sonra 3. doz yoktur — rapel sadece 1. doz → 2. doz için çalışır

---

## Özet Değişiklikler

| Değişiklik | Dosya |
|------------|-------|
| `ileri_gebe_gorev_kontrol` güncelle (stok_id, miktar, gorev_tipi) | Yeni migration |
| Yeni `ileri_gebe_asi_tamamla` RPC | Yeni migration |
| Task detay modalı: ILERI_GEBE_ASI tespiti + mini form | `js/ui.js`, `index.html` |
| Rapel görev date picker | `js/ui.js` |
| `api.js` rpcInvalidate listesine ekle | `js/api.js` |
