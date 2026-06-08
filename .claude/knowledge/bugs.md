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

## [2026-06-08] BUG-054 Doğum sonrası laktasyon padok geçişi
- Kaynak: kullanıcı
- Modül: supabase (dogum_kaydet)
- Önem: düşük
- Durum: **çözüldü — zaten çalışıyordu** ✅
- Açıklama: dogum_kaydet RPC anne hayvanı SET grup='Sağmal (Laktasyonda)', padok='Sağmal Padok' yapıyor. Canlı DB incelendi, son 3 doğum (148, 168, Test inek 3) hepsi Sağmal Padok'ta.
- İlgili commit: mevcut

## [2026-06-08] BUG-056 Protokol ilaç uygulaması: modal açılıyor ama görev kapanmıyor
- Kaynak: kullanıcı
- Modül: ui.js + supabase (hizli_uygulama RPC + _etken_kod_bul + trg_dinle_uygulama)
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: `_etken_kod_bul` `drug_administrations` lookup yapıyor (ilk kullanımda boş olduğu için NULL dönüyor) → trigger skip → görev kapanmıyor.
- Fix: `_etken_kod_bul` önce `stok.drug_product_id` FK kullanıyor, fallback olarak brand_name ILIKE.
- İlgili commit: hotfix/2026-06-08

## [2026-06-08] BUG-057 Tedavi planı/görev entegrasyonu eksik — 3. gün kabul etmiyor
- Kaynak: kullanıcı
- Modül: ui.js (gorevTedaviGunDone) + supabase (treatment_day_tamamla, gorev_tamamla)
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: `caseDayTamamla` (plan view'dan) `treatment_day_tamamla` çağırıyor ama gorev_log'u kapatmıyor. IDB stale cache → `gorev_tamamla` için gorev bulunamıyor, `.catch(()=>{})` ile sessiz geçiyor. DB incelemede: Day 3 treatment_days.tamamlandi=true ama gorev_log.tamamlandi=false.
- Fix: `treatment_day_tamamla` DB'de gorev_log'u da atomik kapatıyor. `caseDayTamamla` js'den IDB lookup kaldırıldı.
- İlgili commit: hotfix/2026-06-08

## [2026-06-08] BUG-060 hizli_uygulama stok_hareket.id UUID type hatası
- Kaynak: kullanıcı (canlı test)
- Modül: supabase (hizli_uygulama RPC)
- Önem: kritik
- Durum: **çözüldü** ✅
- Açıklama: `hizli_uygulama` içinde `gen_random_uuid()::text` → `stok_hareket.id uuid` kolonuna text insert ediliyordu. PostgreSQL'de text→uuid implicit cast yok → "column 'id' is of type uuid but expression is of type text" hatası.
- Root cause: `stok_hareket.id` uuid column, ama DB fonksiyonu `::text` cast ile yazılmış.
- Fix: `gen_random_uuid()::text` → `gen_random_uuid()` (migration + ground_truth güncellendi)
- Tetikleyici: ILAC tipli görev "Tamamlandı Olarak İşaretle" → hizli_uygulama RPC çağrısı
- İlgili commit: hotfix/2026-06-08 b2e870e

## [2026-06-08] BUG-055 İleri gebeler listesi sıra + yanlış padok uyarısı
- Kaynak: kullanıcı
- Modül: ui.js (renderIleriGebeler)
- Önem: orta
- Durum: **çözüldü** ✅
- Açıklama: İleri gebeler listesinde sıra numarası yoktu ve Kuru/Gebe Padok dışındaki hayvanlar görsel uyarı almıyordu.
- Fix: İnekler `1)`, `2)`, düveler `D-1)`, `D-2)` format. `gebelik_protokol_kontrol` RPC artık padok alanı döndürüyor; yanlış padokta kırmızı arka plan + 🔴 Transfer! etiketi.
- İlgili commit: hotfix/2026-06-08 be2fe62

## [2026-06-08] BUG-059 Tedavi günü alt seans (sabah/öğle/akşam bölünmesi)
- Kaynak: kullanıcı
- Modül: ui.js + supabase (treatment_days, add_treatment_day)
- Önem: orta
- Durum: beklemede — özellik isteği, önce tasarım gerekli
- Açıklama: Aynı tedavi günü içinde birden fazla seans yapılamıyor (sabah/öğle/akşam). Önceki tasarımda Gün 1a, 1b, 1c gibi sub-gün yapısı planlanmıştı ama uygulanmamış.
- Önerilen: treatment_days.seans_no veya sub-day tablosu. Tasarım kararı alındıktan sonra implemente edilecek.
- İlgili commit: —

## [2026-06-08] BUG-058 Done olan görevler stoktan ürün çekmedi
- Kaynak: kullanıcı
- Modül: supabase (gorev_tamamla RPC)
- Önem: yüksek
- Durum: tasarım kararı bekleniyor
- Açıklama: `add_drug_administration` çağrılınca stok ANINDA düşülüyor. TEDAVI_GUN gorev_log'da stok_id/miktar yok. ILAC tipi görevler (dogum_kaydet'ten) de stok_id içermiyor.
- Seçenekler: A) Görev done'da stok seçtir (hizli_uygulama yönlendir), B) Mevcut tasarım koru + dokümante et
- İlgili commit: —

## [2026-06-06] BUG-054 Çıkan hayvan işlem geçmişinde UUID görünüyor
- Kaynak: kullanıcı
- Modül: ui.js (global geçmiş render)
- Önem: düşük
- Durum: kısmen çözüldü — yeni çıkışlar için fix var, eski çıkışlar hâlâ UUID
- Açıklama: hayvan_durum_view WHERE durum='Aktif' → çıkan hayvan state'den düşüyor → kupe çözülemiyor → UUID fallback
- Fix: submitCikis localStorage ege_exited_kupe cache, render fallback eklendi (commit 90720bf)
- Kalıcı çözüm: BUG-053 ile birlikte — cikis_yap RPC islem_log'a CIKIS_YAPILDI yazmalı, snapshot'ta kupe_no saklanmalı
- İlgili commit: 90720bf

## [2026-06-06] BUG-053 Sürüden çıkma islem_log'a loglanmıyor
- Kaynak: kullanıcı
- Modül: supabase (cikis_yap RPC)
- Önem: düşük
- Durum: yeni — acelesi yok
- Açıklama: cikis_yap RPC çalışıyor ama islem_log'a CIKIS_YAPILDI tipi kaydı atmıyor. İşlem geçmişinde çıkış görünmüyor.
- Tetikleyici: Hayvan sürüden çıkarıldığında islem_log boş kalıyor
- İlgili commit: bilinmiyor

## [2026-06-06] BUG-052 Vaka iptali (geri al) çalışmıyor
- Kaynak: kullanıcı
- Modül: forms.js + ui.js
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: pullTables'ta islem_log eksikti → VAKA_ACILDI IDB'ye gelmiyordu → ✕ Sil butonu gizli kalıyordu. ga-hid input da editde kayboldu → crash.
- Fix: pullTables + islem_log, openCaseDet retry, math onay (geri-al + çıkış), ga-hid geri eklendi
- İlgili commit: 33ce85f, 418e5c0

## [2026-06-05] BUG-049 Timezone — 02:00 TR saatinde doğum kaydı reddediliyor
- Kaynak: kullanıcı
- Modül: supabase (RPC / DB fonksiyonları)
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: DB UTC çalışıyor, TR UTC+3. Gece 00:00–02:59 arası `p_tarih > CURRENT_DATE` guard yanlış fırlıyordu.
- Fix: 3 fonksiyonda `CURRENT_DATE` → `(NOW() AT TIME ZONE 'Europe/Istanbul')::date` (tohumlama_kaydet, tohumlama_tekrar_kaydet, gebelik_kaydet_manual)
- İlgili commit: 20260605000002_timezone_fix.sql

## [2026-06-05] BUG-050 Duplikat kontrol mekanizmaları — doğum / tohumlama / gebelik
- Kaynak: kullanıcı
- Modül: forms.js + ui.js + supabase
- Önem: orta
- Durum: **kapatıldı — gerçek bug yok** ✅
- Açıklama: Scout tamamlandı (~20 kontrol noktası). ÇAKIŞMA-3 (fn_gebe_gorev_yarat trigger + ileri_gebe_gorev_kontrol RPC) incelendi — her ikisinde de WHERE NOT EXISTS guard var, idempotent. Canlıda 0 duplicate gorev_log satırı doğrulandı. Tasarım gereği ikili koruma.
- İlgili commit: bilinmiyor — BUG-012 ile ilişkili

## [2026-06-05] BUG-051 Doğum sonrası stale state — Anyonik görev devam ediyor, ileri gebeler güncellenmez
- Kaynak: kullanıcı
- Modül: ui.js + supabase (dogum_kaydet RPC sonrası)
- Önem: yüksek
- Durum: **çözüldü** ✅
- Açıklama: (1) `20260603000001` migration CREATE OR REPLACE sırasında BESLEME iptal bloğu düşürülmüştü. (2) `submitBirth` pullTables'ında `tohumlama` eksikti. (3) `window.__ileriGebeListesi` in-memory cache doğum sonrası temizlenmiyordu.
- Tetikleyici: Doğum kaydedildikten sonra UI yenilemeden kontrol edildiğinde
- İlgili commit: a45fc0d (migration+ground_truth+api.js), 3141568 (forms.js filter+pullTables)

## [2026-06-05] BUG-011 Duplikat fonksiyon tanımları — ayarlar modülü
- Kaynak: repomix analizi
- Modül: app.js + ui.js (veya forms.js)
- Önem: orta
- Durum: yeni
- Açıklama: Aşağıdaki fonksiyonlar birden fazla dosyada tanımlı. Hangisinin aktif olduğu script yükleme sırasına bağlı.
  - `ayarlarHekimEkle()` — 2x
  - `ayarlarHekimKaydet()` — 2x
  - `ayarlarSpermaEkle()` — 2x
  - `ayarlarSpermaKaydet()` — 2x
  - `bildirimAc()` — 2x
  - `bildirimIzniAl()` — 2x
  - `bildirimKontrol()` — 2x
- Tetikleyici: Ayarlar/bildirim modülü kullanıldığında (hangi versiyon çalışacağı belirsiz)
- İlgili commit: repomix-2026-06-05

## [2026-06-05] BUG-012 Benzer işlev — tohumlama/doğum entry point'leri
- Kaynak: repomix analizi
- Modül: forms.js + ui.js
- Önem: orta
- Durum: yeni — incelenmeli
- Açıklama: Aynı domain akışına birden fazla entry point var, çakışma riski yüksek:
  - `tohSonuc(sonuc, btn)` vs `tohSonucKaydet()` — forms.js içinde, biri diğerini çağırıyor mu?
  - `submitInsem(btn)` vs `openInsemSafe(kupeNo)` vs `_openInsemIntercept(hayvan, bekliyor)` — 3 farklı tohumlama başlatıcı
  - `dogumYaptiAc(hayvanId,kupe,tohTarih,sperma)` vs `submitBirth(btn)` — 2 doğum başlatıcı
  - `_uremeDogum(el)` vs `dogumYaptiAc(...)` — üreme panel vs direkt açma
  - `_uremeTohumlama(el)` vs `submitInsem(btn)` — üreme panel vs form submit
- Tetikleyici: Tohumlama/doğum kaydı yapılırken hangi fonksiyonun DB'ye yazdığı belirsiz
- İlgili commit: repomix-2026-06-05

## [2026-06-05] BUG-013 Benzer işlev — görev tamamlama akışı
- Kaynak: repomix analizi
- Modül: ui.js
- Önem: orta
- Durum: yeni — incelenmeli
- Açıklama: Görev tamamlama için birden fazla fonksiyon:
  - `gorevTedaviGunDone()` — tedavi günü tamamlama
  - `_gorevStokTamamlaSubmit(gorevId, hayvanId, padokHedef)` — stok gerektiren görev
  - `_gorevStokSecVeTamamla(gorev)` — stok seçim + tamamla
  - `kaydetTaskEdit(btn, t, degisen)` — görev düzenleme kaydı
  Ortak bir `gorevTamamla(gorevId, params)` helper'ı eksik olabilir.
- Tetikleyici: Farklı görev tipleri tamamlandığında
- İlgili commit: repomix-2026-06-05

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
- Durum: **çözüldü** ✅
- Açıklama: dataTrafficTekGonder fonksiyonu offline kuyruğu gönderirken ilgili tablolara direkt insert/update yapıyordu. Backend validasyonu ve RPC guard'ları atlanıyordu.
- Tetikleyici: Offline'dan online'a geçişte kuyruk gönderilirken
- İlgili commit: feature/gwen-bug007-fix → gwen/dev (19ecaf8)
- Çözüm: RPC_MAP tablosu + buildRpcParams() helper ile tüm offline işlemler artık RPC kullanıyor

## [2026-05-30] BUG-010 Tanımlar Panel Scroll Reset (Kronik)
- Kaynak: kullanıcı
- Modül: ui.js
- Önem: orta (UX irritant)
- Durum: yeni — 3 deneme başarısız
- Açıklama: Tanımlar panelinde (İlaç Sınıfları, Hastalıklar, Kategoriler) herhangi bir CRUD işleminden sonra scroll en başa dönüyor.
- Tetikleyici: loadTanimlarPanel() çağrılması — ekleme/silme/düzenleme
- İlgili commit: d59bb70 (son deneme)
- Denenen çözümler:
  1. el.parentElement.scrollTop save + requestAnimationFrame restore — başarısız
  2. Loader innerHTML kaldırma + setTimeout(0) — başarısız
  3. _keepScroll overflow-y:hidden freeze tekniği — başarısız
- HTML yapısı: div#tanimlar-panel > div(header) > div#tanimlar-tabs > div(overflow-y:auto) > div#tanimlar-panel-body
- Scroll container: tanimlar-panel-body'nin parentElement (flex:1;overflow-y:auto)
- _findScroller + _keepScroll utility mevcut (ui.js top-level)
- Araştırılacak: prompt() native dialog scroll bozuyor olabilir, mobile Safari position:fixed + overflow uyumsuzluğu, accordion display:none toggle etkisi, çift loadTanimlarPanel çağrısı yarışı

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
