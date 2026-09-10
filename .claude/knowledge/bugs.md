# Bug Sinyalleri

Bu dosya erp-debug-agent ve arge-analyst tarafından doldurulur.
Orkestratör oturum açılışında bu dosyayı okur ve briefing'e dahil eder.

## 🔴 Aktif Bug'lar (henüz çözülmedi)

| BUG ID | Modül | Önem | Durum | Commit |
|--------|-------|------|-------|--------|
| [BUG-XXX](#2026-06-13-bug-xxx-modal-router-android-geri-tuşu-stabil-değil) | js/utils/modal.js + js/app.js | orta (UX) | AKTİF — 2 alt bug tespit edildi | 6c4cfbe (kısmi) |
| [TB-001](#2026-06-20-tb-001-_sb_code_search-tip-hatası-kod-araması-yarı-bozuk) | tools-bank server.py (_sb_code_search) | orta | AKTİF 🔴 — try/except yutuyor | — |
| [TB-002](#2026-06-20-tb-002-semantic_search-search_all-supabase-rpc-gecikmesi) | tools-bank server.py (_sb_search/_sb_code_search) | düşük | AKTİF 🔴 — ~10s JWT/RLS gecikme | — |
| [TB-003](#2026-06-20-tb-003-cloudflare-bge-m3-intermittent-degrade-arama-kalitesi) | tools-bank embedding (CF bge-m3) | düşük | AKTİF 🔴 — dış servis, fallback aktif | — |
| [GT-B2](#2026-06-25-gt-b2-ground_truth-kalan-header-dollar-quote-bozukluklari) | supabase/migrations/99999999999999_ground_truth.sql | düşük | AKTİF 🔴 — workflow'u bozmuyor (LSP canlıdan beslenir) | 3fd0305 (B kapandı) |
| [BE-H-3](#2026-07-05-be-h-3-_trg_gorev_parent_kapandi-delete-vs-update-tutarsız-ölçüt-dormant) | supabase (_trg_gorev_parent_kapandi) | düşük (dormant) | BACKLOG — kullanıcı kararı: zararsız, ertelendi | — |
## ✅ Son Çözülen Bug'lar

| BUG ID | Modül | Önem | Durum | Commit |
|--------|-------|------|-------|--------|
| [BUG-XXX-DETAY-MODAL-KUPE-NO-CLICK](#2026-06-13-bug-xxx-detay-modal-kupe-no-click-dom-onclick-→-html-attribute) | index.html + js/ui.js | orta (UX) | ✅ çözüldü | 684534f |
| [BUG-XXX-TEDAVI-ORPHAN](#2026-06-13-bug-xxx-tedavi-orphan-legacy-şema-fk-cascade-yok) | supabase (gorev_log) | orta (UX) | ✅ çözüldü | a4a5336 |
| [CI-001](#2026-07-06-ci-001-e2e-tests-workflow-webkit-tarayıcısı-kurulu-değil) | .github/workflows (E2E Tests) | orta (CI güvenilirliği) | ✅ çözüldü | 3314ee9 |
| [TB-004](#2026-07-07-tb-004-goose-lsp-bridge-pyright-workspaceconfiguration-deadlock) | tools-bank scripts/goose-lsp-bridge.py (yeni) | orta | ✅ çözüldü | f9f12a9 |

> **Yeni bug tespit edilince buraya ekle + en alta detaylı entry yaz.**

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

## [2026-06-13] BUG-XXX-DETAY-MODAL-KUPE-NO-CLICK DOM onclick → HTML attribute
- Kaynak: kullanıcı (somut örnek: m-task-det "136")
- Modül: index.html + js/ui.js (3 detay modal)
- Önem: orta (UX)
- Durum: **çözüldü** ✅
- Açıklama: Detay modal'larında (m-task-det, m-case-det, m-toh-det) hayvan kupe no yazısına tıklayınca hayvan kartı açılmıyordu. 6c4cfbe modal router (pushState/back) sonrası DOM property onclick modal router ile çakışıyordu.
- Root cause:
  - `td-hayvan`, `cd-hayvan`, `td2-hayvan` elementlerinde `el.onclick = () => {...}` DOM property olarak atanıyordu
  - 6c4cfbe `closeM`'e `history.back()` ekledi → popstate listener `.modal.on` arar → modalı kapatır
  - DOM property onclick bazı tarayıcılarda modal router ile race condition'da override ediliyor
- Fix yaklaşımı:
  - HTML attribute onclick: `<div onclick="if(this.dataset.hid){closeM(...);openDet(this.dataset.hid)}">` (render sırasında sabit bağlı)
  - JS tarafında sadece `dataset.hid = hayvan.id` set et (hayvan varsa) veya `delete dataset.hid` (yoksa)
  - `cursor:pointer` style ile görsel feedback
- Değişen dosyalar:
  - `index.html` (3 satır): 3 detay modal başlığına onclick + cursor:pointer
  - `js/ui.js` (9 satır): 3 yerde DOM property onclick kaldırıldı, `dataset.hid` set/delete eklendi
- Net: +9 / -15 satır
- Modal router uyumu: HTML attribute onclick her zaman DOM'a sabit → `closeM` `history.back()` çağırsa bile çalışır
- İlgili commit: 684534f
- Detaylı analiz: `memory/2026-06-13-detay-modal-hayvan-link-fix.md`

## [2026-06-09] BUG-061 Hayvan kartı geçmiş — gorev/uygulama girişlerine tıklayınca hayvan kartı yeniden açılıyor
- Kaynak: kullanıcı
- Modül: ui.js (_gecmisEntryHtml, _detRenderGecmis)
- Önem: orta
- Durum: **çözüldü** ✅
- Açıklama: Hayvan kartı Geçmiş sekmesinde görev (gorev) ve uygulama (uygulama) girişlerine tıklayınca ilgili detay açılmak yerine hayvan kartı kendisi yeniden açılıyordu.
- Root cause:
  - `gorev` tipi (TEDAVI_GUN dışı): `oc = onclick="openDet('${data.hayvan_id}')"` → kendi kartını açıyor
  - `uygulama` tipi: `oc = onclick="openDet('${data.hayvan_id}')"` → kendi kartını açıyor
  - `_detRenderGecmis` bu tipler için overrideOc geçmiyor
  - `overrideOc` fix'i sadece `islem` tipi kapsıyor
- Fix yaklaşımı:
  - `_detRenderGecmis`'te `gorev` için: TEDAVI_GUN → openCaseDet korunsun, diğerleri → `overrideOc=''` (tıklama yok, henüz görev detay modal'ı yok)
  - `_detRenderGecmis`'te `uygulama` için: `overrideOc=''` (zaten sağlık tabında gösteriliyor)
  - Görev detay modal'ı eklenirse o açılabilir (BUG-059 ile ilişkili)
- İlgili commit: 302d6e1

## [2026-06-10] BUG-064 Protokol uygulama — E vitamini görevi stok düşer ama kapanmıyor (BUG-060v2)
- Kaynak: kullanıcı (canlı test)
- Modül: supabase (`_etken_kod_bul` RPC — `drug_classes` sınıf eşleşmesi)
- Önem: yüksek
- Durum: ✅ **FIX KABUL EDİLDİ** (2026-06-10) — canlıda 3 fonksiyon güncellendi (Faz 0/1/2/3 geçti, 4 düzeltme uygulandı, subagent review APPROVED 10/10, `pg_get_functiondef` ile post-deploy doğrulama yapıldı). **Kullanıcı kararı: test edilmeden fixed kabul edildi**, sorun olursa yeniden bakılacak. Faz 4 (5 test senaryosu) ertelendi — Senaryo D/E stokta A/C vit ürünü olmadığı için zaten koşulamazdı.
- Açıklama: 135 numaralı hayvana CAROFERTIN-E uygulandığında `uygulama_log.etken_kod=NULL` kaydediliyor. `_etken_kod_bul` `drug_classes.class_name='Yağda Eriyen Vitaminler'` için `ILIKE '%E Vit%'` eşleşmesi başarısız (E'den sonra " " değil "riyen " geliyor). NULL etken_kod → `fn_dinle_uygulama` trigger `IF NEW.etken_kod IS NOT NULL` koşulunda FALSE → `_gorev_dinle` çağrılmıyor → `gorev_log.tamamlandi=false` kalıyor. Stok yine düşüyor (stok_hareket INSERT bağımsız çalışıyor).
- **İSİM ÇAKIŞMASI:** Kullanıcı "60" numarası verdi, eski BUG-060 (UUID cast, e0f563d) farklı bug. Bu BUG-064 ID'si ile kayıt altına alındı.
- **Bulgu:** `fn_dinle_uygulama` trigger'ı (L9463-9470) + `_gorev_dinle` helper'ı (L9224-9251) zaten doğru kurulmuş. Asıl fix `_etken_kod_bul` E_VIT bloğu.
- **Önerilen fix (YAKLAŞIM 2 — 2 SQL fix, 1 migration, satır referansları Rev 6'da düzeltildi):**
  - **Fix #1:** `_etken_kod_bul` L9213 → `v_class_name ILIKE '%E Vit%'` korunsun, **öncesine** `v_active_ing ILIKE '%E Vitamini%'` eklensin (en spesifik, öncelikli)
  - **Fix #2:** `hizli_uygulama` L9256-9306 → `uygulama_log` INSERT'ten sonra, `stok_hareket`'ten önce `islem_log` INSERT (audit trail). Kolonlar: `tip`, `ana_hayvan_id`, `ref_id`, `ref_tablo`, `snapshot jsonb NOT NULL`, `kullanici_notu` — `gorev_tamamla` L6596 referans pattern'i
  - **Bonus:** `hizli_uygulama_geri_al` L9309-9342 → audit simetrisi (`tip='HIZLI_UYGULAMA_GERI_AL'`). ⚠️ INSERT L9336-L9338 arasına (DELETE'den ÖNCE), `v_uyg.hayvan_id` kullan (L9317'de record'a alınmış)
  - NULL etken_kod fallback'i yapılmayacak (yanlış görev kapatma riski)
  - JS handler redirect (görev bul → gorev_tamamla) YAPILMAYACAK (yanlış mimari — race condition, mimari bozulma)
- **Mimari felsefe:** "İki kapı, aynı yer" — trigger mimarisi (`fn_dinle_uygulama` L9463-9473 + `_gorev_dinle` L9224-9251) DB transaction içinde atomik. JS'i bu döngüye sokma.
- **Test senaryoları:** A) 135 normal akış, B) geri alma simetrisi, C) gorev_tamamla regression, D) NULL etken_kod edge case, E) C vitamini NULL kalır (yanlış eşleşme önleme)
- **İlgili spec:** `docs/specs/2026-06-10-bug060-protokol-stok-gorev-uyumsuzluk.md` (705 satır, **7 revizyon geçmişi**: Rev 6 line referans + Rev 7 Faz 0 doğrulama + v_uyg.aktif_ing fix, Yaklaşım 2, subagent + Faz 0 APPROVED)
- **İlgili plan:** `.claude/plans/2026-06-10-bug064-impl.md` (213 satır, Rev 7 düzeltmesi dahil, 5 faz: Doğrulama → Yazım → Ground Truth → Deploy → Test → Commit, ~37 dk kaldı Faz 0 sonrası)
- **Faz 0 bulguları:** 5 fonksiyon `pg_get_functiondef` ile canlıdan çekildi (PostgREST `pg_proc`'a erişemez → `supabase_migrate` Management API). `v_hayvan` L8'de DECLARE mevcut, `v_uyg.aktif_ing` kolonu YOK, 5/5 L referansı uyuşuyor
- **İlgili commit'ler:** spec Rev 7 `8c42ccd` (push edildi, main, senkron)

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

## [2026-06-13] Ground Truth Regen Tamamlandı (33/138/12 canlı ile birebir)
- Kaynak: egesut-erp1 pi agent
- Modül: supabase/migrations/99999999999999_ground_truth.sql
- Önem: yüksek
- Durum: **çözüldü** ✅ (commit a2e6d00)
- Açıklama: Ground truth dosyası canlı DB ile birebir eşleşmiyordu (faz1 sonrası drift birikmiş). 19 eski default'lu fonksiyon imzası + 5 view duplicate + 1 orphan tablo (buzagi_takip) dosyada vardı ama canlıda yoktu. 35 yeni default'suz fonksiyon + 1 yeni view (hayvan_durum_analizi) + 3 yeni egesut tablo (tedavi, hayvan_override, vethek_tohumlamalar) canlıda vardı ama dosyada yoktu.
- Yöntem: tools_bank_supabase_migrate ile pg_tables/pg_views/pg_get_functiondef/pg_get_function_identity_arguments kullanıldı, 7 parçaya bölünerek /tmp'ye yazıldı, Python ile dosyaya eklendi.
- Sonuç: 33/33 tablo = 33/138 fonksiyon = 138/12 view = 12+1 (hayvan_durum_analizi eklendi). %100 birebir eşleşme.
- Refs: memory/ground_truth_regen_method.md, memory/mcp_supabase_migrate_patterns.md

## [2026-06-13] BUG-XXX-TEDAVI-ORPHAN: Legacy şema FK cascade yok — 6 stale görev orphaned
- Kaynak: kullanıcı (Android test sırasında tesadüfen fark etti)
- Modül: supabase (gorev_log + tedavi/treatment_days)
- Önem: orta (UX)
- Durum: **çözüldü** ✅ (commit a4a5336, migration 20260613000010)
- Phase: systematic-debugging Phase 1-4 tamamlandı

### Problem
- Eski 'tedavi' şeması kullanımdan kalktı (0 kayıt) ama gorev_log'da 6 TEDAVI_SEANS görevi orphaned kaldı
- FK cascade yoktu, eski plan silindi ama görevler kaldı
- `close_case_with_remaining` (BUG-059) yeni 'cases' şemasını hedefliyor, eski 'tedavi' görevlerini yakalamıyor
- Kullanıcı screenshot: H000088 (Test buzağı cabbiş) için 3 farklı day_id, 6 farklı admin_id, 3'ü açık + 1 tamamlanmış (1'i zaten temizlenmişti)

### Tespit edilen kök neden
1. `tedavi` tablosu → 0 kayıt (eski şema terkedilmiş)
2. `treatment_days` → orphaned'ların day_id'leri yok
3. gorev_log.aciklama JSON içinde `day_id` var ama `treatment_days.id`'de karşılığı yok
4. close_case_with_remaining sadece `cases` tablosuna bağlı görevleri temizliyor (adım 5: `(g.aciklama::jsonb->>'day_id')::uuid = td.id`)

### Regresyon analizi (kullanıcı endişesi)
- ❌ Regresyon YOK — BUG-059 doğru çalışıyor (sadece scope dışı görevler kalmış)
- ❌ Yeni bug değil — eski şemadan kalan FK'sız kayıtlar
- ✅ Mevcut fix'lere dokunulmadı (kuru dönem filter, close_case_with_remaining 5-adım, 345f93a gorev_tipi guard)

### Fix
30 satır migration (`supabase/migrations/20260613000010_legacy_tedavi_orphan_cleanup.sql`):
1. Orphaned TEDAVI_GUN/SEANS (aciklama->day_id tedavi_days'da yok) → `iptal=true` + `kapatan_ref='legacy-tedavi-orphan-cleanup-2026-06-13'`
2. islem_log audit (cleaned_count=6, hayvanlar=[H000088], reason tam)

### TDD Cycle
- **Failing test (dry-run):** 6 orphaned
- **Implementation:** 30 satır SQL
- **Verification (post-deploy):**
  - 0 orphaned ✓
  - 7 toplam açık (13-6) ✓
  - audit kaydı yazıldı ✓

### Pattern (yeni)
**Pattern 9: Legacy Schema Orphan Cleanup**
- Şema değiştiğinde (tedavi → cases) eski kayıtlar orphaned kalabilir
- Detection: `LEFT JOIN parent_tablo ON ... IS NULL` + `aciklama::jsonb` cast
- Cleanup: `iptal=true` + `kapatan_ref` ile audit trail
- Guard: `gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')` + `aciklama ~ '^\{.*\}$'` (345f93a pattern)

### Kapsam dışı (kasıtlı)
- ~~Recurring engine~~ — DEFERRED, ayrı iş
- ~~tedavi tablosu DROP~~ — 0 kayıt, ileride audit trail kirletir
- ~~Savunma trigger~~ — BUG-059 cases şemasında cascade var, gerek yok

### İlgili
- close_case_with_remaining (BUG-059)
- 345f93a (gorev_tipi guard)
- kuru dönem post-mortem (2026-05-18, `!t.iptal` filter)

## [2026-06-13] BUG-XXX: Modal router — Android geri tuşu stabil değil
- Kaynak: kullanıcı (Android test)
- Modül: js/utils/modal.js + js/app.js
- Önem: orta (UX)
- Durum: **AKTİF 🔴** — 6c4cfbe commit'i kısmi fix, kullanıcı test'te "davranış stabil değil" raporladı
- Phase: systematic-debugging Phase 1 (root cause investigation)
- Açıklama: 32 modaldan sadece 3'ünde history.pushState vardı (protokol-bs, proto-detay-bs, det). Diğer 29 modal için Android geri tuşu = "önceki sayfaya git". 6c4cfbe commit'inde modal.js openM/closeM/mClose'a pushState/back eklendi + app.js popstate listener başına "açık modal varsa kapat" bloğu eklendi. Kullanıcı test'te **davranış stabil olmadığını** bildirdi.

### Tespit edilen 2 alt bug (Phase 1'de bulundu, henüz düzeltilmedi)

**BUG-XXX-A: `.modal.on` selector inline açılan modalları YAKALAMIYOR**
- `protokol-bs`, `proto-detay-bs` gibi modallar `openM` değil **inline `display:flex`** ile açılıyor (`class="modal"` ama `.on` class'ı YOK)
- Popstate listener'da `document.querySelectorAll('.modal.on')` aranıyor → bunları görmüyor
- Sonuç: bu modallar açıkken geri tuşu → sentinel/sayfa branch'ına düşüyor → arka sayfa değişiyor
- Düzeltme önerisi: `getComputedStyle(m).display !== 'none'` kontrolü ekle veya state-based yaklaşıma geç (`e.state?.modal` veya `e.state?.protokol`)

**BUG-XXX-B: `closeM` form reset'i popstate'te çağrılmıyor**
- `m-animal` gibi modallar `closeM` içinde form alanlarını sıfırlıyor (`a-devlet`, `a-kupe`, `a-dt` vb.)
- Popstate'te sadece `classList.remove('on')` yapılıyor → form datası kalıyor
- Sonuç: sonraki açılışta eski veriler görünebilir (veri sızıntısı riski)
- Düzeltme önerisi: popstate'te `closeM(id)` çağır veya classList.remove + form reset'i birlikte yap

### Kullanıcıdan beklenen Phase 1 bilgisi (henüz gelmedi)
- [ ] Hangi modal/sayfada test ettin?
- [ ] Tam olarak ne oluyor? (sekmeli: kapanmıyor / arka sayfa değişiyor / çift geri / başka)
- [ ] Konsol hata var mı? (Android Chrome → geliştirici seçenekleri)
- [ ] En stabil olmayan senaryo (adım adım)

### Phase planı
- Phase 1 (kök neden) — DEVAM EDİYOR
- Phase 2 (pattern analizi) — bekliyor (asilama-impl branch'inde çalışan tam router var, karşılaştırılacak)
- Phase 3 (hipotez) — bekliyor
- Phase 4 (fix + test) — bekliyor

### Yapılan değişiklikler
- 6c4cfbe: modal.js + app.js kısmi fix (pushState/back eklendi ama inline display:flex + form reset bugları kaldı)

### İlgili dosyalar
- js/utils/modal.js (openM, closeM, mClose)
- js/app.js (popstate listener, app.js:100-135)
- js/ui.js:862, 927, 1754 (inline display:flex ile açılan 3 modal)
- feature/asilama-impl branch — referans router kodu
- .worktrees/asilama-impl/js/app.js:99-134 (çalışan popstate)

## [2026-06-20] TB-001 _sb_code_search tip hatası — kod araması yarı bozuk
- Kaynak: claude (tools-bank embedding fix sırasında tespit)
- Modül: tools-bank `/root/tools-bank/mcp_server/server.py` (`_sb_code_search`)
- Önem: orta
- Durum: **AKTİF 🔴**
- Açıklama: `_sb_code_search(vec, limit)` çağrısı `can't multiply sequence by non-int of type 'float'` hatası fırlatıyor. `semantic_search` içinde try/except ile yutuluyor (fatal değil) ama **kod embedding araması (code_embeddings) çalışmıyor** — sadece memory_notes (`_sb_search`) sonuç dönüyor.
- Tetikleyici: `semantic_search` / `search_all` çağrısı (code_embeddings tarafı sessizce boş döner)
- Olası kök neden: cosine/çarpım işleminde vec bir liste (sequence) ile float çarpılmaya çalışılıyor — muhtemelen Supabase'den dönen embedding string/list olarak parse edilip float'a çevrilmeden kullanılıyor, ya da fallback SHA256 vektörü (list) RPC'ye yanlış formatta gidiyor.
- Not: CF degrade + SHA256 fallback ile ilişkili olabilir (fallback vektör formatı) — TB-003 ile birlikte bakılmalı.
- İlgili commit: — (henüz fix yok)

## [2026-06-20] TB-002 semantic_search / search_all Supabase RPC gecikmesi
- Kaynak: claude (embedding fix doğrulaması sırasında ölçüldü)
- Modül: tools-bank `server.py` (`_sb_search` + `_sb_code_search` Supabase RPC)
- Önem: düşük
- Durum: **AKTİF 🔴**
- Açıklama: `_embed` 8s wall-clock cap'e alındıktan sonra bile `semantic_search` ~18s sürüyor. Kalan ~10s embedding değil, **Supabase RPC çağrıları** (`_sb_search` 0.7s + `_sb_code_search` + JWT/RLS gate). Pi de "memory_search FTS5 → Supabase RLS gate, JWT fetch yavaş" demişti.
- Etki: MCP proxy ~30s timeout'unun altında kalıyor (hang yok) ama aramalar ideal değil (yavaş).
- Olası kök neden: her çağrıda JWT yeniden alınıyor olabilir (service_role key cache yok), ya da RLS policy ağır. Bkz. [[project_toolsbank_service_role_key]].
- Tetikleyici: `semantic_search`, `search_all`, `memory_search`
- İlgili commit: —

## [2026-06-20] TB-003 Cloudflare bge-m3 intermittent degrade — arama kalitesi
- Kaynak: claude + pi (doğrudan ölçüm: 125.93s / 54s / bazen hızlı)
- Modül: tools-bank embedding (CF `@cf/baai/bge-m3` endpoint)
- Önem: düşük (dış servis)
- Durum: **AKTİF 🔴** — mitigasyon devrede
- Açıklama: Cloudflare Workers AI bge-m3 endpoint'i aralıklı ciddi yavaşlıyor (down değil). Mitigasyon: `_embed` artık 8s wall-clock deadline ile keser → SHA256 fallback (`embedded:false`). Tool hang etmez ama **CF yavaşken üretilen embedding'ler semantik DEĞİL** → o sırada eklenen notlar/aramalar düşük kalite. CF düzelince otomatik gerçek embedding'e döner ama eski fallback'li kayıtlar yeniden embed edilmeli.
- Aksiyonlar (sonra): (1) CF düzelince `embedded:false` kayıtları tespit + re-embed. (2) İkincil embedding sağlayıcı (lokal/alternatif API) ekleyip kaliteyi koru. (3) https://www.cloudflarestatus.com izle.
- Mitigasyon kodu: `server.py` `_cf_embed_raw` + `_EMBED_POOL` + `_EMBED_DEADLINE_S=8`
- İlgili memory: `memory/bug_toolsbank_watchdog_goused_loop.md`, Supabase note `df6d2a58`
- İlgili commit: — (mitigasyon uncommitted, /root/tools-bank reposunda)

## [2026-06-25] GT-B2 ground_truth kalan header + dollar-quote bozuklukları
- Kaynak: claude (Görev B Faz 2 review sırasında tam-dosya parse testi)
- Modül: supabase/migrations/99999999999999_ground_truth.sql
- Önem: **düşük** — workflow'u BOZMUYOR
- Durum: **AKTİF 🔴** — Görev B kapandı (asıl hedef dogum onarımı tamam), bu kalıntı ayrı
- Açıklama: Görev B (commit 3fd0305) dogum satır-132 bozukluğunu onardı ve audit canlıyla birebir (41 tablo / 12 view / 165 fn). Ancak dosyada ÖNCEDEN VAR OLAN, dogum'dan BAĞIMSIZ başka bozukluklar tespit edildi: (1) ~satır 2528 `public.hekimler` → `CREATE TABLE (` başlığı tamamen eksik, sadece kolonlar duruyor; (2) ~satır 6288 `kizginlik_log` → `$$;-- BUG-6` delimiter+yorum yapışması + `DO $$` eksik çıplak `BEGIN;`. Boş şemaya tam yükleme 785 "syntax error" satırı veriyor ama bu kaskad (tek `$$` desync sonraki ~4000 satırı zehirliyor) — gerçek kök neden bir avuç.
- Neden acil DEĞİL: SQL LSP'nin şema kaynağı `refresh_lsp_schema.sh` ile **canlı Supabase → Neon** (Management API), bu dosya DEĞİL. ground_truth.sql sadece insan/agent referans dokümanı; audit obje **adlarını** doğrular (header'lar sağlam), bozuk olan sadece bazı fonksiyon **gövdeleri** (hangi objenin var olduğunu değiştirmez).
- Tetikleyici: dosyayı boş bir postgres'e wholesale `\i` ile yüklemeye çalışmak (normal akışta olmaz).
- Aksiyon (B2, sonra): canlıdan kök-neden objeleri (hekimler + kizginlik_log DO blokları + diğer `$$` desync'leri) yeniden üret, dosya boş şemaya temiz yüklenene kadar. `scripts/ground-truth-audit.sh` + boş-şema parse testi ile doğrula.
- İlgili commit: 3fd0305 (Görev B kapandı)

## [2026-07-05] BE-H-3 `_trg_gorev_parent_kapandi` DELETE vs UPDATE tutarsız ölçüt (dormant)
- Kaynak: OMP triage (`reports/omp-triage-high.md`) + Claude canlı-doğrulama + kullanıcı kararı
- Modül: supabase (`_trg_gorev_parent_kapandi` trigger fonksiyonu, `gorev_log` tablosu)
- Önem: düşük (şu an dormant — hiçbir gerçek kaydı etkilemiyor)
- Durum: BACKLOG (kullanıcı kararı 2026-07-05: "zararı yoksa backloga atalım")
- Açıklama: Trigger'ın iki dalı farklı ölçüt kullanıyor. DELETE dalı: parent silinince, child'ı **kendi tipi** whitelist'te ise (`BESLEME`,`BUZAGI_BAKIM`,`TEDAVI_GUN`,`ILERI_GEBE_ASI`) korur. UPDATE dalı (parent tamamlanır/iptal): child'ı **tipi parent'ın tipine eşitse** korur (`c.gorev_tipi <> NEW.gorev_tipi`). Canlı `gorev_log` verisinde var olan 5 parent→child eşleşmesinin (BESLEME→BESLEME 353, BUZAGI_BAKIM→BUZAGI_BAKIM 54, TEDAVI_GUN→TEDAVI_GUN 48, ILERI_GEBE_ASI→ILERI_GEBE_ASI 8, TEDAVI_GUN→TEDAVI_SEANS 57) HİÇBİRİNDE iki dal farklı sonuç vermiyor — çünkü bugüne kadar hep ya "child tipi=parent tipi" ya da "child tipi zaten whitelist dışı" durumu oluşmuş. Farklılaşma yalnızca HENÜZ VAR OLMAYAN bir kombinasyonda ortaya çıkar: whitelist-dışı bir parent tipinin (örn. `DIGER`) whitelist-içi bir child tipi (örn. `BESLEME`) olursa — silmede korunur, tamamlamada sessizce kapanır.
- Tetikleyici: Bir RPC'nin gelecekte farklı-tip parent→child nesting üretmesi (bugün hiçbir RPC bunu yapmıyor).
- İlgili commit: yok (kod değişikliği yapılmadı, kasıtlı ertelendi)

## [2026-07-06] CI-001 E2E Tests workflow — webkit tarayıcısı kurulu değil
- Kaynak: GitHub Actions run log (`gh run view --log-failed`)
- Modül: `.github/workflows` (E2E Tests iş akışı, Playwright)
- Önem: orta (CI güvenilirliği — gerçek regresyonları maskeliyor)
- Durum: ✅ çözüldü (3314ee9)
- Açıklama: `Error: browserType.launch: Executable doesn't exist at /home/runner/.cache/ms-playwright/webkit-2248/pw_run.sh`. Tüm E2E test dosyaları (60 test, hepsi 3-4ms'de) ve ayrı "Smoke Test (9 critical checks)" job'ı bu yüzden başarısız. 2026-07-06 oturumunda yapılan 8 commit'in TAMAMINDA (BE-H-1/4, Critical #3/#6, sperma temizliği, Medium triage×2) ve hatta saf dokümantasyon commit'lerinde bile aynı hata tekrarlıyor — **10 commit geriye kadar kontrol edildi, hiçbiri geçmemiş**. Yani mevcut kod değişikliklerinden BAĞIMSIZ, kronik bir CI-altyapı sorunu.
- Kök neden (bağımsız olarak yerel ortamda da doğrulandı, bkz. 3bd75ed): `playwright.config.js`'deki proje 'chromium' adını taşısa da `devices['iPhone 14']` preset'i `defaultBrowserType: 'webkit'` döndürüyor — proje aslında WebKit çalıştırıyor. Workflow'un 4 job'ı da sadece `npx playwright install --with-deps chromium` yapıyordu.
- Çözüm: 4 job'da da `--with-deps chromium` → `--with-deps chromium webkit`.
- Not: `Deploy static site to Pages` işi bu sorundan ETKİLENMEDİ — ayrı bir job, bağımsız çalışıyor, canlı site güncel kaldı. Sadece E2E/Smoke test coverage'ı kayıptı.
- Tamamlayıcı düzeltmeler (3bd75ed, aynı oturum): testlerin `page.goto('/')` çağrısı alt-dizinli `baseURL` ile birleşince GH Pages kök 404'üne gidiyordu (`./` ile düzeltildi); `openApp()` helper'ları dashboard'da hiç render edilmeyen `.stat-row` seçicisini bekliyordu (`#pg-dash .sv` ile düzeltildi); `.fab` 3 buton eşleştirip strict-mode ihlali veriyordu (spesifik `data-action` seçiciyle düzeltildi). webkit artık kurulsa bile bu 3 hata olmadan testler yine geçmezdi.
- İlgili commit: 3314ee9 (workflow), 3bd75ed (tamamlayıcı test-suite düzeltmeleri)

## [2026-07-07] TB-004 goose-lsp-bridge — pyright deadlock, 3 katman (workspace/configuration, RLock, reader-thread stdin write)
- Kaynak: goose-worker-lsp (1. katman, worktree `tools-bank-lanes/lsp-bridge`) + Claude (2. ve 3. katman, doğrudan canlı debug) + bir review agent (3. katmanı statik analizle tespit edip doğru teşhis etti)
- Modül: tools-bank `scripts/goose-lsp-bridge.py`
- Önem: orta (yeni özelliği tamamen blokluyordu, canlıyı hiç etkilemedi — merge öncesi yakalandı)
- Durum: **✅ çözüldü** (commit `9c2407f` + `f9f12a9` + `1f71d86`, ana `tools-bank` reposunda)
- Açıklama: Goose'un yeni lazy-start LSP-MCP köprüsünde (JS/TS→typescript-language-server, Python→pyright-langserver, SQL→mevcut postgrestools daemon'ı) Python tarafı çalışmıyordu — `lsp_diagnostics`/`lsp_hover`/`lsp_definition` .py dosyalarında sonsuza kadar bekliyordu. Sorun TEK bir bug değil, üç ayrı katmanda üç ayrı deadlock riski çıktı — her biri düzeltildikten sonra bir sonraki ortaya çıktı.
- **1. katman (Goose buldu, doğru ama yetersiz):** pyright `initialize` handshake'inde server→client bir `workspace/configuration` REQUEST'i gönderiyor, bridge cevap vermeyince pyright kendi isteğinin cevabını bekliyordu. Goose generic bir server-request auto-reply mekanizması ekledi (`_reply_server_request`) — doğru ve gerekli ama tek başına yetmedi.
- **2. katman (Claude, canlı debug ile buldu):** `LSPClient.__init__`'te `self._lock = threading.Lock()` (reentrant OLMAYAN düz kilit). `request()` bu kilidi tutarken (`with self._cond:`) İÇİNDE `self._send()`'i çağırıyor, o da AYNI kilidi AYNI thread'den tekrar almaya çalışıyor — düz `Lock` bunu desteklemez, `request()` kendi kendini kilitliyordu. Fix: `threading.Lock()` → `threading.RLock()`. Aynı turda ayrıca undrained stderr pipe riski de giderildi (`_drain_stderr` daemon thread).
- **3. katman (bir review agent tespit etti, statik analizle — kod hiç değişmemiş olsa da doğruydu):** `_reply_server_request` (reader thread üzerinde, `_reader_loop` içinden çağrılıyor) `_send()`'i çağırıyor, o da eski haliyle DOĞRUDAN `_write_raw()` (bloke eden `stdin.write()+flush()`) yapıyordu — reader thread üzerinde. Eğer child aynı anda kendi stdout'una büyük bir patlama yazmaya çalışıp OS pipe buffer'ı (~64KB) dolup kendi `write()`'ında bloke olursa (örn. pyright'ın ilk büyük `publishDiagnostics` patlaması `workspace/configuration` isteğiyle çakışırsa), reader thread'in stdin'e yazma çağrısı da bloke olur → reader stdout'u boşaltmayı durdurur → child'ın stdout'u dolu kalır → child hep bloke kalır → karşılıklı pipe deadlock'u. Yorum satırı (`# Reply ... outside the lock`) sadece `_cond` kilit çekişmesini çözüyordu, OS pipe buffer deadlock'unu çözmüyordu.
- Fix (3. katman): `_send()` artık `stdin`'e DOĞRUDAN yazmıyor — framed byte'ları bir `queue.Queue`'ya koyuyor, ayrı bir `_writer_thread` bu kuyruktan okuyup gerçek `stdin.write()+flush()`'ı yapıyor. Reader thread artık HİÇBİR ZAMAN yazma çağrısında bloke olmuyor, her zaman stdout'u okumaya devam edebiliyor.
- Doğrulama (canlı, ham kanıt): 400 fonksiyonlu / 2000 satırlık bilerek-hatalı bir `.py` dosyası açıldı → 1200 gerçek diagnostic döndü (hem fix'li hem fix'siz versiyonda — sentetik testte tam deadlock koşulu (config-request + büyük burst'ün TAM ÇAKIŞMASI) yakalanamadı, bu YARIŞ KOŞULU'nun doğası gereği zamanlamaya bağlı olmasından kaynaklanıyor olabilir). Fix sonrası `lsp_hover` ve `lsp_definition` de aynı dosyada doğru sonuç döndürmeye devam etti (regresyon yok). Kod mantığı (statik analiz) sağlam: reader thread artık asla `stdin.write()` çağırmıyor, bu sınıf deadlock yapısal olarak imkânsız hale geldi.
- Not (dürüstlük): Bu 3. katman canlı olarak bizzat TETİKLENEMEDİ (senkron sentetik testte oluşmadı, muhtemelen zamanlamaya bağlı bir yarış koşulu olduğu için) — ama kod okuması kesin: reader thread'in blocking bir syscall'da donma riski gerçekti ve şimdi yapısal olarak yok. Defense-in-depth olarak uygulandı, "kanıtlanmış sürekli tekrarlayan bug" olarak değil "kod incelemesiyle doğrulanmış yapısal risk" olarak değerlendirilmeli.
- Tetikleyici (eskiden, 1-2. katman): `.py` uzantılı herhangi bir dosyada ilk `lsp_diagnostics`/`lsp_hover`/`lsp_definition` çağrısı. (3. katman): büyük bir stdout patlamasıyla bir server→client request'in zamanlama olarak çakışması — deterministik değil.
- İlgili commit: `9c2407f` (bridge+wiring, Goose) + `f9f12a9` (RLock+stderr, Claude) + `1f71d86` (writer-thread, Claude) — hepsi ana `tools-bank` reposunda.
- İlgili memory: `project_goose_acp_bridge` (Milestone #6/#7/#8), vektör DB id 1327
