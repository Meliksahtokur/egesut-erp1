# Repeat Breed Badge — Tasarım Dokümanı

**Tarih:** 2026-05-23
**Durum:** ✅ Uygulandı — 2026-05-23 (commit `09eb113`)
**Güncelleme:** Tasarımdaki tüm adımlar implemente edildi. Tekrar Aşım butonları amber→purple da dahil.

---

## 1. Konsept

Birden fazla tohumlama denemesi olan hayvanlara (`deneme_no >= 2`) hayvan kartında ve tüm listelemelerde 🔁 badge'i gösterilecek.

| Durum | Badge | Renk | Anlamı |
|-------|-------|------|--------|
| **Aktif repeat** | `🔁 2x Aşım` | Amber (`#c97d0a`) | Bu cycle'da 2+ tohumlama yapılmış, hala devam ediyor |
| **Geçmiş repeat** | `🔁 2x Aşım` | Yeşil (`#4e9a2a`) | Önceki cycle'da repeat vardı, bu cycle temiz |

---

## 2. Veri Kaynağı

Halihazırda `loadAnimals()` içinde `globalThis._tohMap` ve `globalThis._bosTohMap` dolduruluyor. Aynı yere üçüncü bir harita eklenir:

```js
globalThis._repeatMap = {
  'bac3b8f8-...': {
    current: 2,    // bu cycle'daki max deneme_no (≥2 = amber)
    pastMax: 3,    // önceki cycle'lardaki max deneme_no (≥2 = yeşil)
  },
  ...
}
```

### 2.1. Hesaplama Mantığı

```js
async function buildRepeatMap() {
  const allToh = await getData('tohumlama');
  const map = {};

  // Her hayvan için tohumlamaları cycle'lara ayır
  // Cycle = Doğum Yaptı/Abort sonrası dönem (deneme_no sıfırlanır)
  for (const t of allToh) {
    if (!map[t.hayvan_id]) map[t.hayvan_id] = { current: 0, pastMax: 0 };
    const entry = map[t.hayvan_id];

    // Sonuc Doğum Yaptı veya Abort ise bu cycle BİTTİ demek.
    // Bundan sonra gelen kayıtlar yeni cycle'a aittir.
    // Aslında deneme_no zaten cycle'a göre atanır:
    //   deneme_no=1 → o cycle'ın ilk tohumlaması
    //   deneme_no≥2 → o cycle'da repeat var

    if (t.sonuc === 'Bekliyor' || t.sonuc === 'Gebe' || t.sonuc === 'Boş') {
      // Bu cycle'a ait bir kayıt
      if (t.deneme_no > entry.current) entry.current = t.deneme_no;
    }
    if (t.sonuc === 'Doğum Yaptı' || t.sonuc === 'Abort') {
      // Bu cycle KAPANDI — current cycle bilgisi pastMax'e taşınır
      // Ama önce bu cycle'ın max deneme_no'sunu pastMax'e yaz
      if (entry.current > entry.pastMax) entry.pastMax = entry.current;
      entry.current = 0; // yeni cycle başladı
    }
  }

  // Son temizlik: eğer current 0 ise ve pastMax var, pastMax korunur
  globalThis._repeatMap = map;
}
```

**Uyarı:** Bu mantık önemli bir varsayıma dayanıyor — her Doğum Yaptı/Abort kaydından SONRA gelen kayıtlar yeni cycle'a aittir. Veri yapısı `deneme_no`'nun per-cycle atanmasıyla uyumludur.

### 2.2. Ne Zaman Çağrılır

```js
// loadAnimals() içinde, gebelik haritalarından hemen sonra:
await buildRepeatMap(); // globalThis._repeatMap'i doldur
```

---

## 3. Badge Kodu

```js
// _animalTagsHtml içine yeni badge:
const _repeat = (globalThis._repeatMap||{})[a.id];
let repeatBadge = '';
if (_repeat) {
  if (_repeat.current >= 2) {
    // Aktif repeat — amber
    repeatBadge = `<span class="repeat-badge amber">🔁 ${_repeat.current}x Aşım</span>`;
  } else if (_repeat.pastMax >= 2) {
    // Geçmiş repeat — green
    repeatBadge = `<span class="repeat-badge green">🔁 ${_repeat.pastMax}x Aşım</span>`;
  }
}
```

### 3.1. CSS Sınıfları (index.html `<style>`)

```css
.repeat-badge{display:inline-block;font-size:.58rem;font-weight:700;padding:2px 7px;border-radius:6px}
.repeat-badge.amber{background:rgba(201,125,10,.15);color:#c97d0a}
.repeat-badge.green{background:rgba(78,154,42,.15);color:#4e9a2a}
```

---

## 4. Etkilenen Yerler

### 4.1. Hayvan Kartı (tüm listelemeler)

| Dosya | Satır | Değişiklik |
|-------|-------|-----------|
| `js/ui.js` | 535-554 (loadAnimals) | `buildRepeatMap()` çağrısı ekle |
| `js/ui.js` | 557-583 (_animalTagsHtml) | `repeatBadge` ekle |
| `index.html` | CSS blok | `.repeat-badge` sınıflarını ekle |

`_animalTagsHtml` şu yerlerden çağrılır → hepsinde badge görünür:
- `renderAnimals()` → Sürü sayfası, dashboard gebe listesi, filtre sonuçları
- Her animal card'da `.a-tags` içinde

### 4.2. Tohumlama Listelerinde

**Üreme → Tohumlama tab** (`_uremeTohumlama`, satır 1522-1553):
- Zaten `t.deneme_no` badge'i yeni eklendi
- Tekrar Aşım butonu amber → `--purple` olacak (renk düzeltmesi)

**Hayvan detay → Üreme tab** (`_detUremeHtml`, satır 760-797):
- Zaten `t.deneme_no` badge'i yeni eklendi

---

## 5. Hücre/Etkileşim Davranışı

- Badge tıklanabilir DEĞİL (sadece bilgi)
- Hayvan kartı zaten tıklanabilir → detay sayfasına gider
- Badge renkleri `.tag` pattern'ı ile uyumlu: yeşil/amber background'lar `.tg`/`.ta` ile aynı ton

---

## 6. Köşe Durumları

| Senaryo | Beklenen |
|----------|----------|
| Hiç tohumlama kaydı yok | Badge gösterilmez |
| Tek tohumlama (`deneme_no=1`), cycle devam ediyor | Badge gösterilmez |
| `deneme_no=2`, cycle devam ediyor (Bekliyor sonuç) | **Amber** "🔁 2x Aşım" |
| `deneme_no=3`, cycle Gebe ile kapandı, yeni cycle'da deneme_no=1 | **Yeşil** "🔁 3x Aşım" |
| Geçmiş cycle'da repeat VAR, şu anki cycle'da da repeat VAR (current=2) | **Amber** "🔁 2x Aşım" (current öncelikli) |
| Hayvan kısır, repeat verisi yok | Kısır badge'i ayrı gösterilir, repeat badge'i kendi mantığıyla çalışır |

---

## 7. Öncelik Sırası

1. Tag'de birden fazla badge varsa sıra: `padok grup gebe hasta abort kısır **repeat**`
2. Repeat badge'i kısır'dan ÖNCE, bosTohBadge'den SONRA gösterilir

---

## 8. Renk Güncellemesi (İkincil)

Repeat badge için amber ve yeşil mevcut. Bu amber kullanımı meşru — gerçek bir "uyarı" anlamı taşıyor (aktif repeat). Geçmiş repeat için yeşil ise "sorun çözülmüş" anlamında.

Ancak **diğer amber kullanımlarının bir kısmı** hala göz yorgunluğu yaratıyor. Bunlar ikinci adımda ele alınacak (bu dokümanın kapsamı dışında).

---

## 9. İmplementasyon Adımları

```
1. index.html CSS → .repeat-badge sınıfları ekle
2. js/ui.js → buildRepeatMap() fonksiyonu ekle (loadAnimals içinde)
3. js/ui.js → _animalTagsHtml içinde repeatBadge oluştur
4. js/ui.js → _uremeTohumlama'daki Tekrar Aşım buton rengi amber → purple
5. Test: 195 için doğru badge rengi geliyor mu kontrol
```

Tahmini süre: ~30 dk
