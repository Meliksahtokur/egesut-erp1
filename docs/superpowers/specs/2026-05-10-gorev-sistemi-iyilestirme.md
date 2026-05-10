# Spec: Görev Sistemi İyileştirmeleri

**Tarih:** 2026-05-10
**Öncelik:** YÜKSEK
**Bağımlılık:** IDB fix tamamlandı (59282b5)

---

## 1. Tamamlanan Görev Detayı + Rapel Tarih Gösterimi

### Mevcut Durum
- `loadTasks('done')` sadece kart gösteriyor, tıklanamıyor
- Rapel bilgisi (child görev tarihi) hiçbir yerde gösterilmiyor

### Hedef
- Tamamlanmış görev kartına tıklayınca detay modal açılsın
- Rapel var ise: "Rapel: 31 Mayıs 2026" bilgisi görünsün
- Geri alma butonu olsun

### Implementasyon

**UI (js/ui.js):**
- `loadTasks('done')` → renderTask'a `onclick="openDoneTaskDet('${t.id}')"` ekle
- Yeni fonksiyon `openDoneTaskDet(id)`:
  - IDB'den görevi + child'ları çek
  - Modal: başlık, tarih, tamamlanma tarihi, hayvan bilgisi
  - Rapel child varsa: "📅 Rapel: {fmtTarih(child.hedef_tarih)}" göster
  - "↩️ Geri Al" butonu

**Done tab kartında rapel tarihi:**
```
renderTask done variant → kart altına:
"Rapel: 31 Mayıs" (küçük yazı, mavi renk)
```

---

## 2. Görev Geri Alma (Undo)

### İş Mantığı
Bir aşı görevi geri alındığında:
1. `gorev_log` → `tamamlandi=false`, `tamamlanma_tarihi=null`
2. `vaccination_log` → ilgili kaydı sil (notes'ta GorevID var)
3. `stok_hareket` → aşı için düşürülen miktarı geri ekle
4. Child görevler (rapel) → SİL (orphan olmasın)

### RPC: `gorev_geri_al(p_gorev_id text)`

```sql
-- 1. Görevi bul
-- 2. vaccination_log'dan GorevID ile eşleşen kaydı bul → sil
-- 3. stok_hareket'ten vaccination_log_id ile eşleşen hareketi bul → sil
-- 4. gorev_log'dan parent_id = p_gorev_id olan tüm child'ları sil
-- 5. gorev_log.tamamlandi = false, tamamlanma_tarihi = null
-- 6. RETURN jsonb{ok: true, silinen_rapel_sayisi, silinen_asi_id}
```

### Kısıtlar
- Sadece son 7 gün içinde tamamlananlar geri alınabilir
- Child görev zaten tamamlanmışsa geri alma YASAKLANIR (uyarı ver)
- UI'da onay modali: "Bu işlem aşı kaydını ve rapel görevini silecektir"

---

## 3. Görev Filtreleme (Kategori)

### Mevcut Durum
- Sekmeler: Bugün | Geciken | Tamamlanan
- Kategori filtresi YOK

### Hedef Filtreler
| Filtre | gorev_tipi eşleşmesi |
|--------|---------------------|
| Tümü | (filtre yok) |
| 💉 Aşı | `ILERI_GEBE_ASI` + `ASI_HATIRLATMA` |
| 💊 Vitamin/Takviye | `ILERI_GEBE` (SC Ademin, E Vitamini) |
| 🔍 Kontrol | `MUAYENE`, `GEBELIK_KONTROL` |
| 💊 Tedavi | `TEDAVI`, `ILAC_UYGULAMA` |
| 🐄 Bakım | `SUTTEN_KESME`, `PADOK_DEGISIM`, `TARTIM` |

### UI Tasarım
- Mevcut sekmelerin ALTINA: chip/tag tarzı yatay scroll filter bar
- Seçili filtre: yeşil arka plan
- `loadTasks` mevcut `f` parametresine ek olarak `_taskKategori` state variable

### Implementasyon
```js
// Yeni state
let _taskKategori = 'all';

// Filter bar HTML (tasks-body üstüne)
const kategoriMap = {
  all: 'Tümü',
  asi: '💉 Aşı',
  vitamin: '💊 Takviye',
  kontrol: '🔍 Kontrol',
  tedavi: '💊 Tedavi',
  bakim: '🐄 Bakım'
};

// loadTasks içinde ek filter:
if(_taskKategori !== 'all') {
  const tipMap = { asi: ['ILERI_GEBE_ASI','ASI_HATIRLATMA'], ... };
  data = data.filter(t => tipMap[_taskKategori].includes(t.gorev_tipi));
}
```

---

## Test Senaryosu

1. Tamamlanan sekmede görev kartına tıkla → detay modal açılır
2. Rapelli görev: rapel tarihi kartda ve modalde görünür
3. "Geri Al" → onay → görev bekleyene döner, rapel siliner, stok düzelir
4. Kategori filtresi: "Aşı" seç → sadece aşı görevleri görünür
5. Child'ı tamamlanmış görev geri alınamaz (uyarı)
