# Bug Sinyalleri

Bu dosya erp-debug-agent ve arge-analyst tarafından doldurulur.
Orkestratör oturum açılışında bu dosyayı okur ve briefing'e dahil eder.

## Format

```markdown
## [YYYY-MM-DD] [BUG-ID] [başlık]
- Kaynak: [arge-analyst | erp-debug-agent | kullanıcı | supabase-log]
- Modül: [ui.js | forms.js | app.js | api.js | supabase | bilinmiyor]
- Önem: [kritik | yüksek | orta | düşük]
- Durum: [yeni | inceleniyor | çözüldü]
- Açıklama: [ne olduğu]
- Tetikleyici: [nasıl oluşuyor]
- İlgili commit: [hash veya "bilinmiyor"]
```

<!-- Buraya bug sinyalleri ekle -->

## [2026-03-27] BUG-001 rpcOptimistic yanlış çağrı — tohumlama sonucu kaydedilmiyor
- Kaynak: erp-explorer (sistem denetimi)
- Modül: ui.js
- Önem: kritik
- Durum: çözüldü
- Açıklama: ui.js:2583'te rpcOptimistic'e string RPC adı yerine callback fonksiyon geçiliyor. Fonksiyon imzası 1. parametre olarak string bekliyor (rpcOptimistic(name, params, opts)). Callback hiç yürütülmüyor — tohumlama sonucu DB'ye yazılmıyor.
- Tetikleyici: Tohumlama sonucu güncelleme (Gebe/Boş/Abort) akışı tetiklendiğinde
- İlgili commit: 7b40d1d

## [2026-03-27] BUG-002 openNotModal duplikat — yükleme sırasına göre farklı davranış
- Kaynak: erp-explorer (sistem denetimi)
- Modül: forms.js + ui.js
- Önem: orta
- Durum: **çözüldü** ✅
- Açıklama: openNotModal fonksiyonu forms.js:319 ve ui.js:663'te iki kez tanımlı. ui.js versiyonu input temizleme adımını içermiyor. Hangisinin geçerli olduğu script yükleme sırasına bağlı.
- Tetikleyici: Not ekleme modalı açılırken
- İlgili commit: gwen/dev-005

## [2026-03-27] BUG-003 selDis duplikat — ui.js versiyonunda tani-btn reset eksik
- Kaynak: erp-explorer (sistem denetimi)
- Modül: app.js + ui.js
- Önem: orta
- Durum: **çözüldü** ✅
- Açıklama: selDis app.js:647'de 2 parametreli, ui.js:2684'te tanımlıydı. ui.js versiyonu silindi, app.js versiyonuna form.reset() eklendi. Duplikat temizlendi.
- Tetikleyici: Tanı seçimi yapıldığında
- İlgili commit: feature/gwen-bug003-fix

## [2026-03-27] BUG-004 Direkt REST bypass — drug_products insert (forms.js:765)
- Kaynak: erp-explorer (sistem denetimi)
- Modül: forms.js
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: drug_products tablosuna direkt .insert() çağrılıyor. RLS policy, trigger ve backend validasyonu atlanıyor.
- Tetikleyici: Yeni ilaç ürünü eklenirken
- İlgili commit: bilinmiyor

## [2026-03-27] BUG-005 Direkt REST bypass — stok update (forms.js:775)
- Kaynak: erp-explorer (sistem denetimi)
- Modül: forms.js
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: stok tablosuna direkt .update() çağrılıyor. Stok tablosu RPC üzerinden yönetilmeli.
- Tetikleyici: İlaç-stok bağlantısı güncellenirken
- İlgili commit: gwen/dev-005-clean (drug_product_ekle RPC içine p_stok_id ile taşındı)

## [2026-03-27] BUG-006 Direkt REST bypass — drugs update (ui.js:1160)
- Kaynak: erp-explorer (sistem denetimi)
- Modül: ui.js
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: drugs tablosuna direkt batch .update() çağrılıyor. RLS policy kontrolü yapılmamış.
- Tetikleyici: Stok-ilaç bağlantısı silinirken
- İlgili commit: gwen/dev-005

## [2026-03-27] BUG-007 Offline kuyruk gönderiminde direkt REST bypass (ui.js:2745,2749)
- Kaynak: erp-explorer (sistem denetimi)
- Modül: ui.js
- Önem: yüksek
- Durum: yeni
- Açıklama: dataTrafficTekGonder fonksiyonu offline kuyruğu gönderirken ilgili tablolara direkt insert/update yapıyor. Backend validasyonu ve RPC guard'ları atlanıyor.
- Tetikleyici: Offline'dan online'a geçişte kuyruk gönderilirken
- İlgili commit: bilinmiyor

## [2026-03-27] BUG-009 tohSonuc() direkt REST PATCH — RPC'ye geçiş yarım kaldı
- Kaynak: erp-debug-agent
- Modül: forms.js
- Önem: kritik
- Durum: **çözüldü** ✅
- Açıklama: forms.js:640 — `write()` REST PATCH kaldırılacak. `tohumlama_sonuc_gebe/bos/bekliyor` RPC'leri oluşturuldu (migration 20260327000001), frontend güncellemesi yapılmadı. Sonraki oturumda `tohSonuc()` fonksiyonu rpcOptimistic'e geçirilecek.
- Tetikleyici: Tohumlama detay modalındaki Gebe/Boş/Bekliyor butonları
- İlgili commit: gwen/dev-005

## [2026-03-27] BUG-008 submitInsem sonrası UI refresh garantisiz — pullTables kaldırıldı
- Kaynak: arge-analyst
- Modül: forms.js
- Önem: orta
- Durum: **çözüldü** ✅
- Açıklama: d562d03 commit'inde submitInsem() içindeki `pullTables(['tohumlama','gorev_log']).then(renderSafe)` çağrısı "RPC otomatik invalidation yapıyor" yorumuyla kaldırıldı. Ancak RPC'nin gerçekten otomatik UI invalidation tetikleyip tetiklemediği doğrulanmamış. Eğer RPC'nin Realtime/websocket kanalı aktif değilse veya invalidation mekanizması çalışmazsa, tohumlama ve görev listesi eski veriyi göstermeye devam eder.
- Tetikleyici: Tohumlama kaydı yapıldıktan sonra liste ekranına dönüldüğünde
- İlgili commit: gwen/dev-005
