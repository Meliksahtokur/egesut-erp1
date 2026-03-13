# EgeSüt ERP – Refactor Roadmap

Bu belge, mevcut kod tabanında yapılacak iyileştirmeleri aşamalı olarak listeler. Her aşama, belirli bir amaca hizmet eden ve birbirini tamamlayan değişiklikler içerir. Aşamalar, bağımlılıkları dikkate alarak sıralanmıştır; bir aşama tamamlanmadan diğerine geçilmemelidir.

---

## Aşama 1 – Altyapı ve Kod Organizasyonu (Hızlı Kazanımlar)

Bu aşama, uygulamanın temelini sağlamlaştırmayı ve gelecekteki değişiklikleri kolaylaştırmayı hedefler.

### 1.1 Global Değişkenlerden State Havuzuna Geçiş
- Mevcut `window._A`, `_S`, `_curPg` vb. global değişkenler kaldırılacak.
- Tek bir `AppState` nesnesi oluşturulacak (ör. `window.__state`).
- State değişikliklerini dinlemek için basit bir EventEmitter veya proxy tabanlı abonelik sistemi eklenecek.
- Tüm render fonksiyonları, ihtiyaç duydukları state'i bu havuzdan alacak.

### 1.2 Sabitlerin Merkezileştirilmesi
- `HEKIMLER`, `SPERMA_LISTESI`, `HASTALIK_KAT`, `LOKASYON_KAT`, `SEMPTOM_KAT`, `GRUP_PADOK` gibi sabit listeleri `config.js` adlı yeni bir dosyaya taşınacak.
- Fallback değerler burada tutulacak; DB'den gelen veriler bu sabitlerin üzerine yazılmayacak, ayrı bir state'te (ör. `__state.diseases`) saklanacak.

### 1.3 Yardımcı Fonksiyonların Ayrıştırılması
- `g()`, `v()`, `cl()`, `dAgo()`, `dFwd()`, `fmtTarih()`, `toast()`, `showDebug()` gibi genel yardımcılar `utils/helpers.js` dosyasına taşınacak.
- `openM`, `closeM`, `mClose` gibi modal yönetim fonksiyonları `utils/modal.js` dosyasında toplanacak.

### 1.4 Autocomplete Sisteminin Tekilleştirilmesi
- `acHayvan`, `acSperma`, `acIlac`, `acDisease` gibi benzer autocomplete fonksiyonları tek bir `setupAutocomplete(inputId, options)` fonksiyonuna indirgenecek.
- `options` parametresi: `dataSource` (veri kaynağı – fonksiyon veya dizi), `displayField`, `valueField`, `onSelect` callback.
- Mevcut autocomplete'ler bu yeni fonksiyonla yeniden yazılacak.

---

## Aşama 2 – Veri Yönetimi ve Senkronizasyon İyileştirmeleri

Bu aşama, IndexedDB ve Supabase ile çalışan veri katmanını daha güvenilir ve performanslı hale getirir.

### 2.1 `write()` Fonksiyonunun Bölünmesi
- `insertOffline(table, data)` – sadece INSERT işlemi yapar, queue'ya ekler.
- `updateOffline(table, id, changes)` – sadece UPDATE işlemi yapar, queue'ya ekler.
- Her iki fonksiyon da ortak bir `enqueue(method, table, data, filter)` fonksiyonunu çağırır.
- Mevcut `write()` çağrıları uygun şekilde değiştirilecek.

### 2.2 Senkronizasyon Motorunun Güçlendirilmesi
- `syncNow` fonksiyonu, queue'daki her kaydı göndermeye çalışırken başarısız olanları atlamak yerine üstel geri çekilme (exponential backoff) ile yeniden deneyecek.
- Her queue öğesine `retryCount` ve `lastAttempt` alanları eklenecek. 5 başarısız denemeden sonra öğe "hata" olarak işaretlenip kullanıcıya bildirilecek (Data Traffic panelinde gösterilecek).
- `pullTables` sırasında sadece gerçekten değişen tabloların çekilmesi için `etag` veya `last_updated` gibi bir mekanizma düşünülebilir (uzun vadeli).

### 2.3 IndexedDB Sorgularının Optimizasyonu
- `getData(table, filterFn)` yerine, filtrelenmiş sorgular için IndexedDB index'leri kullanılacak.
- `gorev_log`, `tohumlama`, `dogum` gibi sık sorgulanan tablolara uygun index'ler eklenecek (migration gerektirmez, sadece IndexedDB store'ları oluşturulurken index tanımlanır – `openDB` içinde).
- Örnek: `gorev_log` için `hayvan_id` ve `tamamlandi` index'leri.

### 2.4 RPC Optimistic Update
- `rpcOptimistic` fonksiyonu, RPC başarılı olduğunda `pullTables` yerine, dönen sonucu kullanarak local state'i güncelleyecek.
- Örneğin `tohumlama_kaydet` RPC'si dönen `tohumlama_id` ile local'e yeni kayıt ekleyecek.
- `pullTables` sadece periyodik olarak (örneğin her 5 dakikada bir) veya kullanıcı manuel yenileme yaptığında çalışacak.

---

## Aşama 3 – UI ve Render İyileştirmeleri

Bu aşama, kullanıcı arayüzünün daha hızlı, daha güvenli ve daha bakımı kolay hale getirilmesini sağlar.

### 3.1 Render Motorunun Hafifletilmesi
- Mevcut `innerHTML` atamaları, sadece değişen kısımları güncelleyecek şekilde yeniden yazılacak (örneğin `insertAdjacentHTML` veya küçük bir virtual DOM kütüphanesi – lit-html).
- Uzun listelerde (hayvan listesi, görev listesi) sayfalama (pagination) veya sanal kaydırma (virtual scrolling) eklenecek.

### 3.2 Olay Yönetiminin Merkezileştirilmesi
- HTML içindeki tüm `onclick`, `oninput` vb. öznitelikler kaldırılacak.
- JavaScript tarafında, sayfa yüklendiğinde (`DOMContentLoaded`) dinamik olarak eklenen elemanlar için event delegation kullanılacak.
- Her bir buton veya etkileşimli eleman, `data-action` gibi bir öznitelikle işaretlenecek; merkezi bir dinleyici bu aksiyonları çalıştıracak.

### 3.3 Modal Bileşenlerinin Sınıflara Dönüştürülmesi
- Her bir modal için ayrı bir sınıf (ör. `AnimalModal`, `BirthModal`, `InsemModal`) oluşturulacak.
- Bu sınıflar, modalın HTML yapısını, açılma/kapanma davranışını, form doğrulamasını ve submit işlemlerini kapsayacak.
- Mevcut `openM`, `closeM` fonksiyonları bu sınıfların örnekleri üzerinden çalışacak.

### 3.4 Toast Bildirim Sisteminin Geliştirilmesi
- `toast` fonksiyonu, birden fazla bildirimi kuyruğa alıp sırayla gösterecek şekilde yeniden yazılacak.
- Bildirim türlerine göre (başarı, hata, uyarı, bilgi) farklı renk ve ikonlar eklenecek.

---

## Aşama 4 – Hata Yönetimi ve Loglama

Bu aşama, uygulamanın kararlılığını artırır ve hata ayıklamayı kolaylaştırır.

### 4.1 Merkezi Hata Yakalama
- Tüm async işlemleri saran bir `withErrorHandling(fn, context)` fonksiyonu yazılacak.
- Bu fonksiyon, hatayı yakalayıp kullanıcıya `toast` ile gösterecek ve ayrıca `console.error` ile detaylı log bırakacak.
- `window.onerror` ve `unhandledrejection` dinleyicileri de bu merkezi mekanizmaya yönlendirilecek.

### 4.2 Kullanıcı Dostu Hata Mesajları
- Teknik hata mesajları (RPC hataları, ağ hataları) kullanıcıya anlaşılır bir dille aktarılacak.
- Örnek: `"Hayvan eklenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin."`

### 4.3 Debug Modu
- `localStorage`'da `debug=true` ayarı yapıldığında, tüm hata detayları ve ek loglar konsola yazılacak.
- Ayrıca, ekranda bir hata paneli açılarak son hatalar listelenebilecek.

---

## Aşama 5 – Veritabanı Migration ve Drift Yönetimi

Bu aşama, veritabanı şemasının kodla tam uyumlu olmasını sağlar.

### 5.1 Eksik Migration'ların Tamamlanması
- `ARCHITECTURE.md`'de belirtilen 013 ve 014 numaralı migration'lar (SQL Editor'dan uygulanmış olanlar) dosya sistemine eklenecek.
- İçerikleri, mevcut canlı veritabanından alınacak (örneğin `supabase db diff --schema public` ile çıkarılacak).

### 5.2 Ground Truth Migration'ı
- Mevcut tüm migration'ların toplamından oluşan bir "ground truth" migration dosyası (örneğin `20260320000000_ground_truth.sql`) oluşturulacak. Bu dosya, her şeyi sıfırdan kurmak için kullanılabilir.
- Ancak normal geliştirme sürecinde bu dosya çalıştırılmayacak, sadece referans olacak.

### 5.3 Migration'ların İdempotent Hale Getirilmesi
- Mevcut migration'lar gözden geçirilecek, eksik `IF NOT EXISTS` veya `DROP IF EXISTS` kontrolleri eklenecek.
- Özellikle `ALTER TABLE ADD COLUMN` işlemleri için `IF NOT EXISTS` kullanılacak.

---

## Aşama 6 – Güvenlik ve XSS Koruması

Bu aşama, uygulamayı olası güvenlik açıklarına karşı korur.

### 6.1 Kullanıcı Girdilerinin Temizlenmesi
- `innerHTML` ile basılan tüm kullanıcı girdileri (hayvan notları, görev açıklamaları vb.) `textContent` ile değiştirilecek veya bir `escapeHtml` fonksiyonundan geçirilecek.
- HTML içinde görüntülenmesi gereken zengin metin (örneğin notlarda satır sonları) için `white-space: pre-wrap` CSS kullanılacak.

### 6.2 RLS ve API Anahtarı Güvenliği
- Supabase anon key'in yetkileri tekrar gözden geçirilecek, gereksiz tablo erişimleri kaldırılacak.
- Tüm yazma işlemlerinin RPC üzerinden yapıldığından emin olunacak (zaten büyük ölçüde öyle).

---

## Aşama 7 – Performans İyileştirmeleri

Bu aşama, uygulamanın daha hızlı çalışmasını sağlar.

### 7.1 Lazy Loading ve Kod Bölme
- Uygulama tek bir `index.html` olduğu için kod bölme mümkün değil. Ancak, nadir kullanılan modallerin (örneğin Ayarlar) içeriği dinamik olarak yüklenebilir (örneğin `import()` ile).
- Alternatif: Tüm JS tek dosyada kalmaya devam edebilir, ancak gereksiz hesaplamalar azaltılabilir.

### 7.2 Debounce ve Throttle Kullanımı
- `filterA` gibi sık çağrılan fonksiyonlarda debounce zaten var. `pullTables` ve `syncNow` için throttle eklenecek.

### 7.3 Gereksiz Render'ların Önlenmesi
- `renderSafe` debounce süresi (60ms) yeterli. Ancak, sadece değişen bölümlerin render edilmesi için daha akıllı bir mekanizma kurulacak (Aşama 3.1 ile birlikte).

---

## Aşama 8 – Test Edilebilirlik ve Kod Kalitesi

Bu aşama, projenin gelecekteki geliştirmeler için daha sağlam bir temele oturmasını sağlar.

### 8.1 ESLint ve Prettier Kurulumu
- `.eslintrc.js` ve `.prettierrc` dosyaları eklenecek.
- Tüm kod tabanı bu kurallara göre formatlanacak.

### 8.2 JSDoc Yorumları
- Özellikle karmaşık fonksiyonlar (örneğin `openDet`, `loadDash`) için JSDoc yorumları eklenecek: parametreler, dönüş değeri, fırlattığı hatalar.

### 8.3 Unit Test Altyapısı (Uzun Vadeli)
- İş mantığını DOM'dan ayırdıktan sonra, Jest veya benzeri bir test framework'ü ile unit testler yazılabilecek.
- İlk etapta en kritik fonksiyonlar (örneğin tarih hesaplamaları, validasyonlar) test edilecek.

---

## Aşama 9 – Dokümantasyon ve Bilgi Aktarımı

### 9.1 README.md Güncellemesi
- Projenin nasıl kurulacağı, geliştirme ortamı, migration'ların nasıl çalıştırılacağı adım adım anlatılacak.
- Mevcut `ARCHITECTURE.md` ve `PROJE_DURUMU.md` ile uyumlu hale getirilecek.

### 9.2 Yeni Geliştiriciler İçin Kılavuz
- Kod tabanının yapısını, önemli fonksiyonları ve akışları açıklayan bir `CONTRIBUTING.md` dosyası eklenecek.

---

## İlerleme Takibi

Her aşama tamamlandığında, bu dosyanın altına tarih ve yapılan işler not edilecektir. Örneğin:

**Aşama 1 Tamamlandı – 2026-03-14**
- Global state havuzu oluşturuldu.
- Sabitler `config.js`'e taşındı.
- Yardımcı fonksiyonlar `utils/` klasörüne ayrıldı.
- Autocomplete sistemi tekilleştirildi.

---

Bu yol haritası, projenin sürdürülebilirliğini ve kalitesini artırmak için atılacak adımları net bir şekilde ortaya koymaktadır. Her aşama, kendi içinde tamamlanabilir ve bir sonraki aşama için temel oluşturur.