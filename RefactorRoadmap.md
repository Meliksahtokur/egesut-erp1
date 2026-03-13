
## Aşama 1 Tamamlandı – 2026-03-14
- **1.2 Sabitlerin Merkezleştirilmesi** tamamlandı.
  - `js/config.js` oluşturuldu, tüm sabit listeleri buraya taşındı.
  - `js/app.js`'deki sabit tanımları kaldırıldı.
  - `index.html`'e script sırası eklendi.

## Aşama 1.1 (kısmi) – 2026-03-14
- `js/state.js` oluşturuldu, merkezi state altyapısı eklendi.
- `index.html`'e script sırasına eklendi.
- Henüz global değişkenler state'e taşınmadı, sadece altyapı hazır.

## Aşama 1.1 – 2026-03-14
- `_A` (hayvanlar listesi) merkezi state'e taşındı.
  - `js/api.js`'de `pullTables` içinde animals çekilip `setState('animals')` yapılıyor.
  - Tüm dosyalarda `_A` yerine `getState('animals')` kullanıldı.
  - `js/state.js` altyapısı aktif hale getirildi.
## Aşama 1.2 – State Geçişi ve Hata Düzeltmeleri – 2026-03-13 19:45 (Türkiye saati, UTC+3)

- **Sorun:** `openM` fonksiyonunda `m-disease` modalı için eski DOM elemanlarına erişiliyordu (semptom listesi, tani butonları). Yeni modalda bu elemanlar olmadığı için hata oluşuyor, uygulama açılmıyordu.
  - **Fix:** İkinci `if (id === 'm-disease')` bloğu kaldırıldı, sadece `_diseasesCache` temizleme ve `loadDiseasesDropdown('')` çağrısı bırakıldı.
- **Sorun:** Global değişkenler (`_A`, `_S`, `_gebeIds`, `_hastaIds`) hâlâ yoğun şekilde kullanılıyordu; state geçişi yarım kalmıştı.
  - **Fix:** Tüm dosyalarda `_A` → `getState('animals')`, `_S` → `getState('stock')` dönüşümü yapıldı. `_gebeIds` ve `_hastaIds` state'e taşındı (getState/setState ile). Otomatik script ile kalan referanslar temizlendi.
- **Sorun:** `config.js`'de `HASTALIK_LISTESI` gibi hardcoded listeler mevcut (mimari ihlal – hastalıklar DB'den gelmeli).
  - **Durum:** Tespit edildi, ancak bu değişiklik daha kapsamlı olduğu için ileriki aşamalara bırakıldı.
.